#Requires AutoHotkey v2.0
#SingleInstance Force

; ====== SETARI ======
; M2Send.ahk NU se porneste: e librarie (#Include) pentru space/z/abc.
; multi.ahk NU se porneste: ar dubla space/3/z.
SCRIPTS := ["space.ahk", "z.ahk", "abc.ahk", "reinviere.ahk"]
NEEDED  := ["M2Send.ahk", "oras.png", "aici.png"]
DELAY := 300
CLOSE_ALL_KEY := "F12"
; ====================

if !A_IsAdmin {
    try {
        Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
    }
    ExitApp
}

missing := ""
for name in NEEDED {
    if !FileExist(A_ScriptDir "\" name)
        missing .= name " (necesar, nu se lanseaza separat)`n"
}
for name in SCRIPTS {
    if !FileExist(A_ScriptDir "\" name)
        missing .= name "`n"
}
if (missing != "") {
    MsgBox("Lipsesc fisiere in " A_ScriptDir ":`n`n" missing)
    ExitApp
}

pids := []
for name in SCRIPTS {
    try {
        Run('"' A_AhkPath '" "' A_ScriptDir "\" name '"', A_ScriptDir, , &pid)
        pids.Push(pid)
    }
    Sleep(DELAY)
}

ToolTip("Pornite " pids.Length " scripturi (+ M2Send inclus). " CLOSE_ALL_KEY " le inchide pe toate.")
SetTimer(() => ToolTip(), -3000)

Hotkey(CLOSE_ALL_KEY, CloseAll)

CloseAll(*) {
    for pid in pids {
        try ProcessClose(pid)
    }
    Send("{sc039 up}")
    ExitApp
}
