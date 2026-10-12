; Clientul din fata: Send. Cele din spate: mesaje in fereastra.
; Comutare scurta pe clientele din spate doar daca idleMs > 0 si nu ai atins
; mouse-ul / tastatura de idleMs ms (nu fura clickul cat lucrezi).

; Maxim 3 clienti, in aceeasi ordine la fiecare runda.
M2Two(game, max := 3) {
    arr := []
    for h in WinGetList(game)
        arr.Push(h)
    n := arr.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index
            if arr[j] > arr[j + 1] {
                tmp := arr[j], arr[j] := arr[j + 1], arr[j + 1] := tmp
            }
        }
    }
    out := []
    loop Min(max, arr.Length)
        out.Push(arr[A_Index])
    return out
}

M2Tap(keyName, hold) {
    Send("{" keyName " down}")
    Sleep(hold)
    Send("{" keyName " up}")
}

M2BgKey(hwnd, keyName, hold) {
    hwnd := Integer(hwnd)
    vk := Integer(GetKeyVK(keyName))
    sc := Integer(GetKeySC(keyName))
    if !vk
        return
    if !sc
        sc := Integer(DllCall("MapVirtualKeyW", "uint", vk, "uint", 0, "uint"))
    lpDown := 1 | (sc << 16)
    lpUp := lpDown | 0xC0000000
    DllCall("PostMessageW", "ptr", hwnd, "uint", 0x0100, "ptr", vk, "uptr", lpDown)
    Sleep(hold)
    DllCall("PostMessageW", "ptr", hwnd, "uint", 0x0101, "ptr", vk, "uptr", lpUp)
    try ControlSend("{Blind}{" keyName "}", , "ahk_id " hwnd)
}

M2UserBusy(idleMs) {
    static hooked := false
    if !hooked {
        ; fara hook-uri, A_TimeIdlePhysical s-ar reseta si la tastele trimise de script
        InstallKeybdHook()
        InstallMouseHook()
        hooked := true
    }
    return A_TimeIdlePhysical < idleMs
        || GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
}

; Pe fiecare client: activare, apoi space de mai multe ori, apoi urmatorul.
M2SpaceRound(ids, keyName, hold, repeats, between) {
    if !ids.Length
        return
    oldMode := A_SendMode
    SendMode("Event")
    SetKeyDelay(-1, 0)
    for id in ids {
        id := Integer(id)
        if !WinExist("ahk_id " id)
            continue
        if !WinActive("ahk_id " id) {
            try WinActivate("ahk_id " id)
            if !WinActive("ahk_id " id) && !WinWaitActive("ahk_id " id, , 0.08)
                continue
        }
        loop repeats {
            Send("{" keyName " down}")
            Sleep(hold)
            Send("{" keyName " up}")
            Sleep(between)
        }
    }
    SendMode(oldMode)
}

M2Burst(ids, keyName, hold := 8) {
    if !ids.Length
        return
    if GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
        return
    oldMode := A_SendMode
    SendMode("Event")
    SetKeyDelay(-1, 0)
    for id in ids {
        id := Integer(id)
        if !WinExist("ahk_id " id)
            continue
        if !WinActive("ahk_id " id) {
            try WinActivate("ahk_id " id)
            if !WinActive("ahk_id " id) && !WinWaitActive("ahk_id " id, , 0.04)
                continue
        }
        Send("{" keyName " down}")
        Sleep(hold)
        Send("{" keyName " up}")
    }
    SendMode(oldMode)
}

M2PressMany(ids, keyName, hold := 30, switchOthers := true, idleMs := 0) {
    if !ids.Length
        return
    oldMode := A_SendMode
    SendMode("Event")
    SetKeyDelay(0, 0)
    prev := WinExist("A")
    switched := false
    for id in ids {
        id := Integer(id)
        if !WinExist("ahk_id " id)
            continue
        if WinActive("ahk_id " id) {
            M2Tap(keyName, hold)
            continue
        }
        if (switchOthers && idleMs > 0 && !M2UserBusy(idleMs)) {
            try WinActivate("ahk_id " id)
            if WinWaitActive("ahk_id " id, , 0.3) {
                Sleep(30)
                M2Tap(keyName, hold)
                switched := true
                continue
            }
        }
        M2BgKey(id, keyName, hold)
    }
    if switched && prev && WinExist("ahk_id " prev) && !WinActive("ahk_id " prev)
        try WinActivate("ahk_id " prev)
    SendMode(oldMode)
}
