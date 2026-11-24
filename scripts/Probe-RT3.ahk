#Requires AutoHotkey v2.0
SetTitleMatchMode 2
CoordMode "Mouse", "Client"

if !A_Args.Length {
    MsgBox "Usage: Probe-RT3.ahk <output-log>"
    ExitApp 2
}
logPath := A_Args[1]
home := EnvGet("RT3_HOME")
if home == "" {
    FileAppend "RT3_HOME is unset`n", logPath
    ExitApp 2
}

if !WinExist("Railroad Tycoon 3") {
    Run '"' home '\RT3.exe"', home
}
if !WinWait("Railroad Tycoon 3", , 60) {
    if WinExist("Program Error") {
        FileAppend WinGetText("Program Error") "`n", logPath
    } else {
        FileAppend "No RT3 window or Program Error dialog`n", logPath
    }
    ExitApp 2
}
WinGetClientPos &x, &y, &w, &h, "Railroad Tycoon 3"
FileAppend "client=" x "," y " " w "x" h "`n", logPath
