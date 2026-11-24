#Requires AutoHotkey v2.0
SetTitleMatchMode 2
CoordMode "Mouse", "Client"
if A_Args.Length < 4 {
    MsgBox "Usage: Invoke-RT3Click.ahk <x> <y> <window-title> <log-file> [count] [hold-ms]"
    ExitApp 2
}
x := Integer(A_Args[1])
y := Integer(A_Args[2])
title := A_Args[3]
logPath := A_Args[4]
count := A_Args.Length >= 5 ? Integer(A_Args[5]) : 1
hold := A_Args.Length >= 6 ? Integer(A_Args[6]) : 0
if !WinExist(title) {
    FileAppend "window not found: " title "`n", logPath
    ExitApp 2
}
WinRestore title
WinActivate title
if !WinWaitActive(title, , 5) {
    FileAppend "window not active: " title "`n", logPath
    ExitApp 2
}
WinGetClientPos , , &width, &height, title
if width != 800 || height != 600 {
    FileAppend "expected 800x600 client, got " width "x" height "`n", logPath
    ExitApp 2
}
MouseMove x, y, 50
Sleep 250
if hold > 0 {
    MouseClick "Left", x, y, 1, 0, "D"
    Sleep hold
    MouseClick "Left", x, y, 1, 0, "U"
} else {
    MouseClick "Left", x, y, count, 0
}
FileAppend "click " x "," y " count=" count " hold=" hold "`n", logPath
