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
    try {
        Run '"' home '\RT3.exe"', home
    } catch Error as e {
        FileAppend "Run failed: " e.Message "`n", logPath
        ExitApp 2
    }
}
if !WinWait("Railroad Tycoon 3", , 60) {
    if WinExist("Program Error") {
        FileAppend WinGetText("Program Error") "`n", logPath
        ControlClick "OK", "Program Error"
        if !WinWait("Railroad Tycoon 3", , 60) {
            FileAppend "No playable RT3 window after dismissing warning`n", logPath
            ExitApp 2
        }
    } else {
        FileAppend "No RT3 window or Program Error dialog`n", logPath
        ExitApp 2
    }
}
WinGetClientPos &x, &y, &w, &h, "Railroad Tycoon 3"
FileAppend "client=" x "," y " " w "x" h "`n", logPath
