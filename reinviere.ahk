#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True
#Include "%A_ScriptDir%\M2Send.ahk"
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
CoordMode("Pixel", "Screen")

; ====== SETARI ======
GAME := "ahk_exe metin2.bin"
IMG_CITY := A_ScriptDir "\oras.png"   ; "Restarteaza in oras" (ancora)
IMG_HERE := A_ScriptDir "\aici.png"   ; "Restarteaza aici" (click direct daca exista)
TOL := 60                ; scade la 40 daca prinde altceva
CLICK_X := 45            ; cat la dreapta de coltul imaginii oras.png
UP := 25                 ; NU sub 25 (siguranta pentru butonul de oras)
CHECK_EVERY := 200       ; ms intre verificari
HOLD_MS := 30            ; cat tine click-ul apasat
HOTKEYNAME := "F11"      ; opreste / reporneste
; ====================

running := false
busy := false
needles := Map()
gdipToken := 0

if !FileExist(IMG_CITY) {
    MsgBox("Nu gasesc imaginea:`n" IMG_CITY "`n`nPune oras.png langa script.")
    ExitApp
}
if (UP < 25) {
    MsgBox("UP este prea mic (" UP "). Sub 25 punctul ar putea ajunge pe butonul de oras. Scriptul se inchide.")
    ExitApp
}

Hotkey(HOTKEYNAME, OnToggle)
Hotkey("F9", (*) => ExitApp())
OnExit(Cleanup)

ShowMsg(t) {
    ToolTip(t, 20, 20)
    SetTimer(() => ToolTip(), -1500)
}

EnsureGdip() {
    global gdipToken
    if gdipToken
        return true
    if !DllCall("LoadLibrary", "str", "gdiplus", "ptr")
        return false
    si := Buffer(24, 0)
    NumPut("uint", 1, si)
    if DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0)
        return false
    gdipToken := token
    return true
}

Cleanup(*) {
    global gdipToken
    if gdipToken {
        DllCall("gdiplus\GdiplusShutdown", "ptr", gdipToken)
        gdipToken := 0
    }
}

LoadNeedle(path) {
    if !FileExist(path) || !EnsureGdip()
        return false
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", path, "ptr*", &pBmp)
        return false
    DllCall("gdiplus\GdipGetImageWidth", "ptr", pBmp, "uint*", &w)
    DllCall("gdiplus\GdipGetImageHeight", "ptr", pBmp, "uint*", &h)
    hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    bi := Buffer(40, 0)
    NumPut("uint", 40, bi, 0)
    NumPut("int", w, bi, 4)
    NumPut("int", -h, bi, 8)
    NumPut("ushort", 1, bi, 12)
    NumPut("ushort", 32, bi, 14)
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
    ob := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
    DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &gfx)
    DllCall("gdiplus\GdipDrawImageRectI", "ptr", gfx, "ptr", pBmp, "int", 0, "int", 0, "int", w, "int", h)
    buf := Buffer(w * h * 4)
    DllCall("RtlMoveMemory", "ptr", buf, "ptr", pBits, "uptr", buf.Size)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBmp)
    DllCall("SelectObject", "ptr", hdc, "ptr", ob)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdc)
    return { w: w, h: h, bits: buf }
}

CaptureClient(id, &w, &h) {
    WinGetClientPos(, , &w, &h, "ahk_id " id)
    if (w < 8 || h < 8)
        return 0
    hdcW := DllCall("GetDC", "ptr", id, "ptr")
    hdcM := DllCall("CreateCompatibleDC", "ptr", hdcW, "ptr")
    bi := Buffer(40, 0)
    NumPut("uint", 40, bi, 0)
    NumPut("int", w, bi, 4)
    NumPut("int", -h, bi, 8)
    NumPut("ushort", 1, bi, 12)
    NumPut("ushort", 32, bi, 14)
    hbm := DllCall("CreateDIBSection", "ptr", hdcM, "ptr", bi, "uint", 0, "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
    ob := DllCall("SelectObject", "ptr", hdcM, "ptr", hbm, "ptr")
    if !DllCall("PrintWindow", "ptr", id, "ptr", hdcM, "uint", 3)
        DllCall("BitBlt", "ptr", hdcM, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdcW, "int", 0, "int", 0, "uint", 0x00CC0020)
    buf := Buffer(w * h * 4)
    DllCall("RtlMoveMemory", "ptr", buf, "ptr", pBits, "uptr", buf.Size)
    DllCall("SelectObject", "ptr", hdcM, "ptr", ob)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdcM)
    DllCall("ReleaseDC", "ptr", id, "ptr", hdcW)
    return buf
}

ColorClose(nOff, nBits, hOff, hBits, tol) {
    return Abs(NumGet(nBits, nOff, "uchar") - NumGet(hBits, hOff, "uchar")) <= tol
        && Abs(NumGet(nBits, nOff + 1, "uchar") - NumGet(hBits, hOff + 1, "uchar")) <= tol
        && Abs(NumGet(nBits, nOff + 2, "uchar") - NumGet(hBits, hOff + 2, "uchar")) <= tol
}

FindNeedleBits(hay, hayW, hayH, needle, &ox, &oy) {
    nw := needle.w, nh := needle.h, nb := needle.bits
    if (nw > hayW || nh > hayH)
        return false
    x0 := hayW // 5
    x1 := hayW - nw - hayW // 5
    y0 := hayH // 4
    y1 := hayH - nh - hayH // 6
    if (x1 < x0 || y1 < y0) {
        x0 := 0, y0 := 0, x1 := hayW - nw, y1 := hayH - nh
    }
    n0 := 0
    nC := ((nh // 2) * nw + (nw // 2)) * 4
    nR := ((nh - 1) * nw + (nw - 1)) * 4
    y := y0
    while y <= y1 {
        x := x0
        while x <= x1 {
            h0 := (y * hayW + x) * 4
            if ColorClose(n0, nb, h0, hay, TOL) {
                hC := ((y + nh // 2) * hayW + (x + nw // 2)) * 4
                hR := ((y + nh - 1) * hayW + (x + nw - 1)) * 4
                if ColorClose(nC, nb, hC, hay, TOL) && ColorClose(nR, nb, hR, hay, TOL) {
                    ok := true
                    stepX := Max(1, nw // 6)
                    stepY := Max(1, nh // 4)
                    ny := 0
                    while ok && ny < nh {
                        nx := 0
                        while nx < nw {
                            if !ColorClose((ny * nw + nx) * 4, nb, ((y + ny) * hayW + (x + nx)) * 4, hay, TOL) {
                                ok := false
                                break
                            }
                            nx += stepX
                        }
                        ny += stepY
                    }
                    if ok {
                        ox := x
                        oy := y
                        return true
                    }
                }
            }
            x++
        }
        y++
    }
    return false
}

FindOnScreen(id, img, &cx, &cy) {
    WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " id)
    if !ImageSearch(&sx, &sy, wx, wy, wx + ww, wy + wh, "*" TOL " " img)
        return false
    cx := sx - wx
    cy := sy - wy
    return true
}

FindHere(id, &tx, &ty) {
    try {
        if FileExist(IMG_HERE) && FindOnScreen(id, IMG_HERE, &hx, &hy) {
            if !needles.Has("here")
                needles["here"] := LoadNeedle(IMG_HERE)
            nw := needles["here"] ? needles["here"].w : 80
            nh := needles["here"] ? needles["here"].h : 20
            tx := hx + nw // 2
            ty := hy + nh // 2
            return true
        }
        if FindOnScreen(id, IMG_CITY, &cx, &cy) {
            tx := cx + CLICK_X
            ty := cy - UP
            return ty >= 0
        }

        WinGetClientPos(, , &ww, &wh, "ahk_id " id)
        hay := CaptureClient(id, &ww, &wh)
        if !hay
            return false

        if FileExist(IMG_HERE) {
            if !needles.Has("here")
                needles["here"] := LoadNeedle(IMG_HERE)
            if needles["here"] && FindNeedleBits(hay, ww, wh, needles["here"], &hx, &hy) {
                tx := hx + needles["here"].w // 2
                ty := hy + needles["here"].h // 2
                return true
            }
        }
        if !needles.Has("city")
            needles["city"] := LoadNeedle(IMG_CITY)
        if needles["city"] && FindNeedleBits(hay, ww, wh, needles["city"], &cx, &cy) {
            tx := cx + CLICK_X
            ty := cy - UP
            return ty >= 0
        }
        return false
    } catch {
        return false
    }
}

BgClick(id, cx, cy) {
    lp := (cy & 0xFFFF) << 16 | (cx & 0xFFFF)
    try {
        PostMessage(0x0200, 0, lp, , "ahk_id " id)
        PostMessage(0x0201, 0x0001, lp, , "ahk_id " id)
        Sleep(HOLD_MS)
        PostMessage(0x0202, 0, lp, , "ahk_id " id)
    }
}

StartWatch() {
    global running
    running := true
    n := M2Two(GAME).Length
    SetTimer(Check, CHECK_EVERY)
    ShowMsg("REINVIERE PORNIT pe " n " clienti")
}

OnToggle(*) {
    global running
    if running {
        running := false
        SetTimer(Check, 0)
        ShowMsg("REINVIERE OPRIT")
    } else {
        StartWatch()
    }
}

Check() {
    global busy
    if busy
        return
    busy := true
    try {
        for id in M2Two(GAME) {
            if !FindHere(id, &tx, &ty)
                continue
            BgClick(id, tx, ty)
            Sleep(180)
        }
    } finally {
        busy := false
    }
}

StartWatch()
