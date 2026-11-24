param(
    [int]$StartupTimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'

if (-not ([System.Management.Automation.PSTypeName]'RT3NativePath').Type) {
    Add-Type @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
public static class RT3NativePath {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern SafeFileHandle CreateFile(string name, uint access, FileShare share,
        IntPtr security, FileMode mode, uint flags, IntPtr template);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern uint GetFinalPathNameByHandle(SafeFileHandle file, StringBuilder path,
        uint capacity, uint flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    public static extern uint GetDriveType(string root);
    public static string GetCanonicalDirectory(string path) {
        SafeFileHandle handle = CreateFile(path, 0,
            FileShare.ReadWrite | FileShare.Delete, IntPtr.Zero, FileMode.Open,
            0x02000000, IntPtr.Zero); // FILE_FLAG_BACKUP_SEMANTICS
        if (handle.IsInvalid) {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        using (handle) {
            uint capacity = 1024;
            while (true) {
                StringBuilder result = new StringBuilder((int)capacity);
                uint length = GetFinalPathNameByHandle(handle, result, capacity, 0);
                if (length == 0) {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                if (length < capacity) {
                    string canonical = result.ToString();
                    if (canonical.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) {
                        return @"\\" + canonical.Substring(8);
                    }
                    if (canonical.StartsWith(@"\\?\", StringComparison.OrdinalIgnoreCase)) {
                        return canonical.Substring(4);
                    }
                    return canonical;
                }
                capacity = checked(length + 1);
            }
        }
    }
}
'@
}

function Test-DirectoryWithin {
    param(
        [string]$Candidate,
        [string]$Root
    )
    $comparison = [StringComparison]::OrdinalIgnoreCase
    if ($Candidate.Equals($Root, $comparison)) {
        return $true
    }
    $prefix = $Root
    if (-not $Root.EndsWith('\')) {
        $prefix = "$Root\"
    }
    return $Candidate.StartsWith($prefix, $comparison)
}

function Resolve-LocalDirectory {
    param(
        [string]$Path,
        [string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Name is unset"
    }
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (([Uri]$fullPath).IsUnc) {
        throw "$Name must be on a local Windows drive, not UNC: $fullPath"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        throw "$Name is not an existing directory: $fullPath"
    }
    $component = Get-Item -LiteralPath $fullPath -Force
    while ($null -ne $component) {
        if ($component.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "$Name contains a junction/symbolic-link component, which is not permitted: $($component.FullName)"
        }
        $component = $component.Parent
    }
    $canonical = [RT3NativePath]::GetCanonicalDirectory($fullPath)
    if (([Uri]$canonical).IsUnc) {
        throw "$Name resolves to a network/UNC directory, which is not permitted: $canonical"
    }
    $root = [IO.Path]::GetPathRoot($canonical)
    if ([string]::IsNullOrWhiteSpace($root) -or [RT3NativePath]::GetDriveType($root) -ne 3) {
        throw "$Name must resolve to a direct local fixed disk: $canonical"
    }
    if ($canonical.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
        return $canonical
    }
    return $canonical.TrimEnd('\')
}

$copy = Resolve-LocalDirectory $env:RT3_HOME 'RT3_HOME'
$saveDir = Resolve-LocalDirectory $env:RT3_SAVE_DIR 'RT3_SAVE_DIR'
$privateOut = Resolve-LocalDirectory $env:RT3_PRIVATE_OUT 'RT3_PRIVATE_OUT'
$exe = Join-Path $copy 'RT3.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Disposable RT3.exe is missing: $exe"
}
if ((Get-Item -LiteralPath $exe -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'The disposable RT3.exe must not be a symbolic link or reparse point'
}

$mutex = [System.Threading.Mutex]::new($false, 'Global\RT3Engine.DisposableLaunch')
$mutexAcquired = $false
try {
    try {
        $mutexAcquired = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $mutexAcquired = $true
        throw 'A previous launcher terminated while holding the launch mutex; verify/restore the GOG registry before retrying'
    }
    if (-not $mutexAcquired) {
        throw 'Another disposable RT3 launcher is active; refusing concurrent registry overrides'
    }
    if (Get-Process RT3 -ErrorAction SilentlyContinue) {
        throw 'RT3 is already running; stop the oracle session before launching'
    }

    $keyPath = 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1445251062'
    $names = @('PATH', 'SAVEGAMEFOLDER', 'EXE', 'WORKINGDIR', 'LAUNCHCOMMAND')
    $original = [ordered]@{}
    foreach ($name in $names) {
        $original[$name] = (Get-ItemProperty -LiteralPath $keyPath -Name $name).$name
    }
    $originalRoot = Resolve-LocalDirectory $original.PATH 'GOG registry PATH'
    if (Test-DirectoryWithin $copy $originalRoot) {
        throw "RT3_HOME must be outside the original installation: $originalRoot"
    }
    if (Test-DirectoryWithin $privateOut $originalRoot) {
        throw 'RT3_PRIVATE_OUT must be outside the original installation'
    }
    $expectedSaveDir = [IO.Path]::GetFullPath((Join-Path $copy 'Saved Games')).TrimEnd('\')
    if (-not $saveDir.Equals($expectedSaveDir, [StringComparison]::OrdinalIgnoreCase)) {
        throw "RT3_SAVE_DIR must be the disposable copy's Saved Games directory: $expectedSaveDir"
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this launcher in an elevated native Windows PowerShell; it does not self-elevate or bypass UAC'
    }

    $recoveryPath = Join-Path $privateOut ("gog-registry-recovery-" + [Guid]::NewGuid().ToString('N') + '.json')
    $recoveryBytes = [Text.Encoding]::UTF8.GetBytes(($original | ConvertTo-Json))
    $recoveryStream = [IO.File]::Open($recoveryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $recoveryStream.Write($recoveryBytes, 0, $recoveryBytes.Length)
    }
    finally {
        $recoveryStream.Dispose()
    }
    $recovery = [IO.File]::ReadAllText($recoveryPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($name in $names) {
        if ($recovery.$name -ne $original[$name]) {
            throw "Recovery snapshot did not round-trip $name; no registry value was changed"
        }
    }

    $process = $null
    try {
        Set-ItemProperty -LiteralPath $keyPath -Name 'PATH' -Value $copy
        Set-ItemProperty -LiteralPath $keyPath -Name 'SAVEGAMEFOLDER' -Value "$copy\"
        Set-ItemProperty -LiteralPath $keyPath -Name 'EXE' -Value $exe
        Set-ItemProperty -LiteralPath $keyPath -Name 'WORKINGDIR' -Value "$copy\"
        Set-ItemProperty -LiteralPath $keyPath -Name 'LAUNCHCOMMAND' -Value "$exe "
        $process = Start-Process -FilePath $exe -WorkingDirectory $copy -PassThru
        $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
        while ($process.MainWindowHandle -eq [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 500
            $process.Refresh()
            if ($process.HasExited) {
                throw "Disposable RT3 exited with code $($process.ExitCode) before creating a game window"
            }
            if ([DateTime]::UtcNow -ge $deadline) {
                throw 'Disposable RT3 did not create a game window before the startup timeout'
            }
        }
    }
    catch {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
        }
        throw
    }
    finally {
        try {
            foreach ($name in $names) {
                Set-ItemProperty -LiteralPath $keyPath -Name $name -Value $original[$name]
            }
        }
        catch {
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force
            }
            throw
        }
    }

    foreach ($name in $names) {
        $actual = (Get-ItemProperty -LiteralPath $keyPath -Name $name).$name
        if ($actual -ne $original[$name]) {
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force
            }
            throw "GOG registry value $name was not restored; recovery snapshot: $recoveryPath"
        }
    }
    Write-Output "Started disposable RT3 PID $($process.Id)"
    Write-Output "Restored and verified original GOG registry values; recovery snapshot: $recoveryPath"
    Write-Output "Use the same elevated PowerShell for AutoHotkey input, and verify Save/Load lists only $saveDir"
}
finally {
    if ($mutexAcquired) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
