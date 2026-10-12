#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True
SendMode("Event")
#Include "%A_ScriptDir%\M2Send.ahk"

; ====== SETARI ======
GAME := "ahk_exe metin2.bin"
KEY := "z"
GAP := 100
HOLD := 10
EVERY := 2000
HOTKEYNAME := "F6"
; ====================

clients := Map()
lastTap := Map()
busy := false

HotIf (*) => WinActive(GAME)
Hotkey(HOTKEYNAME, OnToggle)
HotIf
Hotkey("F9", (*) => ExitApp())

ShowMsg(t) {
    ToolTip(t)
    SetTimer(() => ToolTip(), -1500)
}

OnToggle(*) {
    list := M2Two(GAME)
    if list.Length = 0 {
        ShowMsg("Nu gasesc niciun client metin2")
        return
    }
    allOn := true
    for h in list
        if !clients.Has(h)
            allOn := false
    if allOn {
        for h in list
            clients.Delete(h)
        ShowMsg("OPRIT " KEY " pe " list.Length " clienti")
    } else {
        for h in list
            clients[h] := true
        ShowMsg("PORNIT " KEY " pe " list.Length " clienti")
    }
    SetTimer(Tick, clients.Count ? GAP : 0)
}

Tick() {
    global busy, lastTap
    if busy
        return
    busy := true
    try {
        dead := []
        for id in clients.Clone()
            if !WinExist("ahk_id " id)
                dead.Push(id)
        for id in dead {
            clients.Delete(id)
            lastTap.Delete(id)
        }
        if clients.Count = 0 {
            SetTimer(Tick, 0)
            return
        }
        hit := 0
        for id in clients
            if WinActive("ahk_id " id) {
                hit := id
                break
            }
        if !hit
            return
        if lastTap.Has(hit) && A_TickCount - lastTap[hit] < EVERY
            return
        lastTap[hit] := A_TickCount
        M2Tap(KEY, HOLD)
    } finally {
        busy := false
    }
}
