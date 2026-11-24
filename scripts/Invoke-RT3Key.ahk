#Requires AutoHotkey v2.0
SetTitleMatchMode 2
if A_Args.Length < 3 {
    MsgBox "Usage: Invoke-RT3Key.ahk <key> <window-title> <log-file>"
    ExitApp 2
}
key := A_Args[1]
title := A_Args[2]
logPath := A_Args[3]
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
if WinActive(target) != window {
    FileAppend "RT3 lost focus before key`n", logPath
    ExitApp 2
}
Send key
FileAppend "key " key "`n", logPath
