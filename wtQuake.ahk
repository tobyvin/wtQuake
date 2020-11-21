#NoEnv
#SingleInstance, Force
#NoTrayIcon
#MaxThreadsPerHotkey 2

IniRead, PATH, wtQuake.ini, WindowsTerminal, path, "C:\Users\tobyv\scoop\apps\WindowsTerminal-preview\current\WindowsTerminal.exe"
IniRead, ARGS, wtQuake.ini, WindowsTerminal, args, "-f"
IniRead, HEIGHT_RATIO, wtQuake.ini, Window, height, 0.25
IniRead, WIDTH_RATIO, wtQuake.ini, Window, width, 0.4425
IniRead, AUTOHIDE, wtQuake.ini, Window, autohide, 0
IniRead, ACTIVE_DISPLAY, wtQuake.ini, Window, active_display, 0
IniRead, ANIMATION_SPEED, wtQuake.ini, Window, animation_speed, 5
PROC := "WindowsTerminal.exe"

SendMode Input
DetectHiddenWindows, On
OnExit("ExitFunction")

#`::ToggleApp()
#+`::ToggleAutoHide()

StartApp(app, args, procName) {
    prevPIDs := GetPIDs(procName)
    Run %app% %args%,,, pid

    if (pid) {
        return pid
    }

    newPIDs := GetPIDs(procName)
    Sort, prevPIDs
    Sort, newPIDs

    for idx, newPID in newPIDs
        if (newPID != prevPIDs[idx])
        return newPID
}

GetPIDs(procName) {
    static wmi := ComObjGet("winmgmts:root\cimv2")

    pids := []
    for proc in wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" procName "'")
        pids.Push(proc.processId)

    return pids
}

ProcessExists(pid) {
    Process, Exist, %pid%
    return (ErrorLevel == pid)
}

GetDisplay() {
    global ACTIVE_DISPLAY
    If (!ACTIVE_DISPLAY)
        return { x: 0, y: 0, width: A_ScreenWidth, height: A_ScreenHeight }

    CoordMode, Mouse, Screen
    MouseGetPos, x, y
    SysGet, count, MonitorCount
    loop %count% {
        SysGet, screen, Monitor, %A_Index%
        if (x >= screenLeft and x <= screenRight and y >= screenTop and y <= screenBottom) {
            return { x: screenLeft, y: screenTop, width: screenRight - screenLeft, height: screenBottom - screenTop }
        }
    }
}

GetPosition() {
    global HEIGHT_RATIO, WIDTH_RATIO 
    screen := GetDisplay()
    pos := {}
    pos.width := WIDTH_RATIO * screen.width
    pos.height := HEIGHT_RATIO * screen.height
    pos.x := (screen.width - pos.width) / 2 + screen.x
    pos.y := screen.y
    return pos
}

Activate(window) {
    global AUTOHIDE, ANIMATION_SPEED
    pos := GetPosition()

    SetWinDelay, 0
    WinShow, ahk_id %window%
    WinMove, ahk_id %window%,, % pos.x, -pos.height, pos.width, pos.height
    WinActivate, ahk_id %window%
    WinSet AlwaysOnTop, On, ahk_id %window% 
    WinSet, Transparent, Off, ahk_id %window% 
    If (ANIMATION_SPEED) {
        y := -pos.height
        While, y < pos.y
            WinMove, ahk_id %window%,, % pos.x, y+=ANIMATION_SPEED, pos.width, pos.height
    }
    WinMove, ahk_id %window%,, % pos.x, pos.y, pos.width, pos.height

    If (AUTOHIDE) {
        WinWaitNotActive, ahk_id %window%
        Hide(window)
    }

}

Hide(window) {
    global ANIMATION_SPEED
    pos := GetPosition()
    SetWinDelay, 0
    If (ANIMATION_SPEED){
        While, pos.y > -pos.height 
            WinMove, ahk_id %window%,, % pos.x, pos.y-=ANIMATION_SPEED, pos.width, pos.height
    }
    WinSet AlwaysOnTop, Off, ahk_id %window% 
    WinSet, Transparent, 0, ahk_id %window% 
    WinMinimize, ahk_id %window%
    WinHide, ahk_id %window%
}

IsActive(window) {
    IfWinActive, ahk_id %window%
        return true
    return false
}

IsHidden(window) {
    DetectHiddenWindows, Off
    if WinExist("ahk_id" . window)
        return false
    return true
}

GetWindow(pid) {
    WinGet, windows, List, ahk_pid %pid%
    return windows ? windows1 : 0
}

PID(newPID:=""){
    static pid := ""
    if (newPID)
        pid := newPID
    else 
        return pid
}

ToggleApp() {
    global PATH, ARGS, PROC
    static pid := ""
    ; DetectHiddenWindows, On
    init := false
    if (!ProcessExists(pid)) {
        pid := StartApp(PATH, ARGS, PROC)
        PID(pid)
        WinWait, ahk_pid %pid%
        Sleep, 400
        Send, ^b
        init := true
    }
    window := GetWindow(pid)
    if (window) {
        if ( init || IsHidden(window) )
            Activate(window)
        else 
            Hide(window)

    } else {
        MsgBox, 0x10, "Bad window", % "The process " PROC " (" pid ") doesn't have any windows."
        pid := ""
    }
}

ToggleAutoHide() {
    global AUTOHIDE
    AUTOHIDE := !AUTOHIDE
    IniWrite, % AUTOHIDE, wtQuake.ini, Window, autohide
}

ExitFunction() {
    pid := PID()
    WinClose ahk_pid %pid%
}