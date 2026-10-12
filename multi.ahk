#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True
SendMode("Event")
#Include "%A_ScriptDir%\M2Send.ahk"

; All-in-one alternativ. Nu-l porni impreuna cu mafia.ahk.
; ====== SETARI ======
GAME := "ahk_exe metin2.bin"
KEYS := [["sc039", 50], ["3", 500], ["z", 2000]]
HOLD := 20
SWITCH_OTHERS := true
WORK_SAFE := true
; ====================

active := Map()
busy := false
M2_GAME := GAME
M2_WORK_SAFE := WORK_SAFE

#HotIf WinActive(GAME)

F7:: {
    id := WinExist("A")
    if active.Has(id) {
        active.Delete(id)
        ShowMsg("OPRIT pe acest client")
    } else {
        active[id] := Map()
        ShowMsg("PORNIT pe acest client")
    }
    SetTimer(Tick, active.Count ? 30 : 0)
}

#HotIf

F9:: ExitApp()

ShowMsg(t) {
    ToolTip(t)
    SetTimer(() => ToolTip(), -1500)
}

Tick() {
    global busy
    if busy
        return
    busy := true
    try {
        now := A_TickCount
        ids := []
        due := Map()
        for id, last in active.Clone() {
            if !WinExist("ahk_id " id) {
                active.Delete(id)
                continue
            }
            ids.Push(id)
            for k in KEYS {
                name := k[1]
                gap := k[2]
                if (!last.Has(name) || now - last[name] >= gap) {
                    last[name] := now
                    if !due.Has(name)
                        due[name] := []
                    due[name].Push(id)
                }
            }
        }
        for name, list in due
            M2PressMany(list, name, HOLD, SWITCH_OTHERS)
        if (active.Count = 0)
            SetTimer(Tick, 0)
    } finally {
        busy := false
    }
}
