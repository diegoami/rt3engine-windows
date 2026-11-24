#Requires AutoHotkey v2.0
SetTitleMatchMode 2
CoordMode "Mouse", "Client"
if A_Args.Length < 4 {
    MsgBox "Usage: Invoke-RT3Click.ahk <x> <y> <window-title> <log-file> [count]"
    ExitApp 2
}
x := Integer(A_Args[1])
y := Integer(A_Args[2])
title := A_Args[3]
logPath := A_Args[4]
count := A_Args.Length >= 5 ? Integer(A_Args[5]) : 1
window := WinExist(title)
if !window {
    FileAppend "window not found: " title "`n", logPath
    ExitApp 2
}
target := "ahk_id " window
if WinGetTitle(target) != "Railroad Tycoon 3" || WinGetProcessName(target) != "RT3.exe" {
    FileAppend "not the RT3 game window: " title "`n", logPath
    ExitApp 2
}
WinRestore target
WinActivate target
if WinWaitActive(target, , 5) != window {
    FileAppend "window not active: " title "`n", logPath
    ExitApp 2
}
WinGetClientPos , , &width, &height, target
if width != 800 || height != 600 {
    FileAppend "expected 800x600 client, got " width "x" height "`n", logPath
    ExitApp 2
}
if x < 0 || x >= width || y < 0 || y >= height {
    FileAppend "coordinates outside client: " x "," y "`n", logPath
    ExitApp 2
}
MouseMove x, y, 50
Sleep 250
if WinActive(target) != window {
    FileAppend "RT3 lost focus before click`n", logPath
    ExitApp 2
}
MouseClick "Left", x, y, count, 0
FileAppend "click " x "," y " count=" count "`n", logPath
