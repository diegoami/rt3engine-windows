#Requires AutoHotkey v2.0
SetTitleMatchMode 2
if A_Args.Length < 3 {
    MsgBox "Usage: Invoke-RT3Key.ahk <key> <window-title> <log-file>"
    ExitApp 2
}
key := A_Args[1]
title := A_Args[2]
logPath := A_Args[3]
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
Send key
FileAppend "key " key "`n", logPath
