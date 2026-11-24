param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [int]$DelaySeconds = 0
)

if ($DelaySeconds -gt 0) {
    Start-Sleep -Seconds $DelaySeconds
}
Add-Type -AssemblyName System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'RT3Window').Type) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RT3Window {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr dc, uint flags);
}
'@
}
$processes = @(Get-Process RT3 -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
if ($processes.Count -ne 1) {
    throw "Expected exactly one RT3 game window, found $($processes.Count)"
}
$process = $processes[0]
[void][RT3Window]::ShowWindow($process.MainWindowHandle, 9)
Start-Sleep -Milliseconds 500
$rect = New-Object RT3Window+RECT
if (-not [RT3Window]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
    throw 'Cannot read RT3 window bounds'
}
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
    throw 'Invalid RT3 window bounds'
}
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$dc = [IntPtr]::Zero
try {
    $dc = $graphics.GetHdc()
    if (-not [RT3Window]::PrintWindow($process.MainWindowHandle, $dc, 2)) {
        throw 'PrintWindow failed for the RT3 game window; no screen-crop fallback is permitted'
    }
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    if ($dc -ne [IntPtr]::Zero) {
        $graphics.ReleaseHdc($dc)
    }
    $graphics.Dispose()
    $bitmap.Dispose()
}
Write-Output "Captured ${width}x${height} from the RT3 window to $OutputPath"
