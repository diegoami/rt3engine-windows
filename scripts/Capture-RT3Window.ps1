param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [int]$DelaySeconds = 0
)

if ($DelaySeconds -gt 0) {
    Start-Sleep -Seconds $DelaySeconds
}
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RT3Window {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
$process = Get-Process RT3 -ErrorAction Stop | Select-Object -First 1
[void][RT3Window]::ShowWindow($process.MainWindowHandle, 9)
[void][RT3Window]::SetForegroundWindow($process.MainWindowHandle)
Start-Sleep -Milliseconds 500
$rect = New-Object RT3Window+RECT
[void][RT3Window]::GetWindowRect($process.MainWindowHandle, [ref]$rect)
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
    throw 'Invalid RT3 window bounds'
}
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}
Write-Output "Captured ${width}x${height} to $OutputPath"
