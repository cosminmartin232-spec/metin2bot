#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True
SendMode("Event")
SetKeyDelay(-1, 0)
#Include "%A_ScriptDir%\M2Send.ahk"

; ====== SETARI ======
GAME      := "ahk_exe metin2.bin"
KEY       := "sc004"     ; sc004 = tasta 3 (mantia)
GAP       := 25          ; doar verifica; nu schimba fereastra (asta taia space-ul)
HOLD      := 20
EVERY     := 250
TOGGLEKEY := "F8"
INFOKEY   := "F7"
EXITKEY   := "F9"
; =======================================

enabled := Map()
lastTap := Map()
busy := false
M2_GAME := GAME
M2_WORK_SAFE := false

HotIf (*) => WinActive(GAME)
Hotkey(TOGGLEKEY, OnToggle)
HotIf
Hotkey("^!1", (*) => ToggleIdx(1))
Hotkey("^!2", (*) => ToggleIdx(2))
Hotkey("^!3", (*) => ToggleIdx(3))
Hotkey(INFOKEY, OnInfo)
Hotkey(EXITKEY, (*) => ExitApp())

SetTimer(Tick, GAP)

ShowMsg(t, ms := 2000) {
    ToolTip(t)
    SetTimer(() => ToolTip(), -ms)
}

CountOn() {
    n := 0
    for h, isOn in enabled
        if isOn
            n++
    return n
}

IsClient(h) {
    return h && WinExist("ahk_id " h " " GAME)
}

DoToggle(h, label) {
    enabled[h] := !enabled.Get(h, false)
    ShowMsg(label (enabled[h] ? " PORNIT" : " OPRIT") "  |  clienti activi: " CountOn())
}

OnToggle(*) {
    list := GetClients()
    if list.Length = 0 {
        ShowMsg("Nu gasesc niciun client metin2")
        return
    }
    allOn := true
    for h in list
        if !enabled.Get(h, false)
            allOn := false
    for h in list
        enabled[h] := !allOn
    ShowMsg((allOn ? "OPRIT" : "PORNIT") " pe " list.Length " clienti")
}

GetClients() {
    return M2Two(GAME)
}

ToggleIdx(i) {
    clients := GetClients()
    if i > clients.Length {
        ShowMsg("Clientul " i " nu exista (gasite: " clients.Length ")")
        return
    }
    DoToggle(clients[i], "Client " i)
}

OnInfo(*) {
    exe := "?"
    try exe := WinGetProcessName("A")
    ShowMsg("Fereastra activa: " exe
        "`nClienti metin2 gasiti: " WinGetList(GAME).Length
        "`nClienti activati: " CountOn(), 5000)
}

Tick() {
    global busy, lastTap
    if busy
        return
    busy := true
    try {
        dead := []
        for h, isOn in enabled {
            if !WinExist("ahk_id " h)
                dead.Push(h)
        }
        for h in dead {
            enabled.Delete(h)
            lastTap.Delete(h)
        }
        hit := 0
        for h, isOn in enabled
            if isOn && WinActive("ahk_id " h) {
                hit := h
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
