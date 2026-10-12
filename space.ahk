#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True
SendMode("Event")
#Include "%A_ScriptDir%\M2Send.ahk"

; ====== SETARI ======
GAME := "ahk_exe metin2.bin"
KEY := "sc039"           ; sc039 = bara de spatiu
CYCLE := 300             ; fiecare client e revizitat la 300 ms, indiferent daca sunt 2 sau 3
READY := 40              ; dupa ce fereastra e in fata, jocul are nevoie de timpul asta ca sa primeasca space
HOTKEYNAME := "F10"
TURN_KEYS := ["sc01E", "sc020"]   ; A, D - pe rand, ca sa se roteasca spre mobi
TURN_EVERY := 1000                ; ms intre rotiri, pe fiecare client
TURN_HOLD := 80                   ; cat tine A/D apasat (mai mult = se roteste mai mult)
; Space ramane apasat cand fereastra trece in spate: jocul nu vede ridicarea tastei
; si ataca singur in continuare. La fiecare vizita space e apasat din nou.
; ====================

clients := Map()
lastTurn := Map()
turnIdx := Map()
busy := false
turn := 0
lastSwitch := 0

HotIf (*) => WinActive(GAME)
Hotkey(HOTKEYNAME, OnToggle)
HotIf
Hotkey("F9", (*) => ExitApp())
OnExit((*) => Send("{" KEY " up}"))

ShowMsg(t) {
    ToolTip(t)
    SetTimer(() => ToolTip(), -1500)
}

ReleaseAll(list) {
    prev := WinExist("A")
    SendMode("Event")
    for h in list {
        if !WinExist("ahk_id " h)
            continue
        try WinActivate("ahk_id " h)
        if WinWaitActive("ahk_id " h, , 0.2) {
            Sleep(READY)
            Send("{" KEY " up}")
        }
    }
    Send("{" KEY " up}")
    if prev && WinExist("ahk_id " prev)
        try WinActivate("ahk_id " prev)
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
        SetTimer(Tick, 0)
        for h in list
            clients.Delete(h)
        ReleaseAll(list)
        ShowMsg("OPRIT Space pe " list.Length " clienti")
        return
    } else {
        for h in list
            clients[h] := true
        ShowMsg("PORNIT Space pe " list.Length " clienti")
    }
    SetTimer(Tick, clients.Count ? 20 : 0)
}

Tick() {
    global busy, turn, lastSwitch
    if busy
        return
    busy := true
    try {
        ids := []
        for id in clients.Clone() {
            if !WinExist("ahk_id " id) {
                clients.Delete(id)
                continue
            }
            ids.Push(id)
            if ids.Length = 3
                break
        }
        if ids.Length = 0 {
            turn := 0
            SetTimer(Tick, 0)
            return
        }
        if (A_TickCount - lastSwitch < CYCLE // ids.Length)
            return
        lastSwitch := A_TickCount
        turn := Mod(turn, ids.Length) + 1
        id := ids[turn]
        SendMode("Event")
        SetKeyDelay(-1, 0)
        if !WinActive("ahk_id " id) {
            try WinActivate("ahk_id " id)
            if !WinActive("ahk_id " id) && !WinWaitActive("ahk_id " id, , 0.15)
                return
            Sleep(READY)
        }
        Send("{" KEY " down}")
        now := A_TickCount
        if !lastTurn.Has(id) || now - lastTurn[id] >= TURN_EVERY {
            lastTurn[id] := now
            idx := Mod(turnIdx.Get(id, 0), TURN_KEYS.Length) + 1
            turnIdx[id] := idx
            k := TURN_KEYS[idx]
            Send("{" k " down}")
            Sleep(TURN_HOLD)
            Send("{" k " up}")
            Send("{" KEY " down}")
        }
    } finally {
        busy := false
    }
}
