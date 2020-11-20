#NoEnv
#SingleInstance, Force
#NoTrayIcon
#MaxThreadsPerHotkey 2

Global CONFIG := GetConfig()
SplitPath, PATH, PROC
SendMode Input
DetectHiddenWindows, On
OnExit("ExitFunction")

#`::ToggleApp()

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

GetConfig() {
    cfg := {}
    ; IniRead, cfg["path"], wtQuake.ini, WindowsTerminal, path, "wt"
    ; IniRead, cfg["args"], wtQuake.ini, WindowsTerminal, args, "-f"
    ; IniRead, cfg["process"], wtQuake.ini, WindowsTerminal, process, "WindowsTerminal.exe"
    ; IniRead, cfg["active_display"], wtQuake.ini, Window, active_display, 0
    ; IniRead, cfg["width_ratio"], wtQuake.ini, Window, width_ratio, 0.5
    ; IniRead, cfg["height_ratio"], wtQuake.ini, Window, height_ratio, 0.25
    ; IniRead, cfg["autohide"], wtQuake.ini, Window, autohide, 0
    ; IniRead, cfg["animation_speed"], wtQuake.ini, Window, animation_speed, 5

    ; cfg.path := path
    ; cfg.args := args
    ; cfg.process := process
    ; cfg.active_display := active_display
    ; cfg.width_ratio := width_ratio
    ; cfg.height_ratio := height_ratio
    ; cfg.autohide := autohide
    ; cfg.animation_speed := animation_speed

    cfg.path := "wt"
    cfg.args := "-f"
    cfg.process := "WindowsTerminal.exe"
    cfg.active_display := 0
    cfg.width_ratio := 0.5
    cfg.height_ratio := 0.25
    cfg.autohide := 0
    cfg.animation_speed := 5
    return cfg 
}

GetDisplays() {

    displays[]
    SysGet, count, MonitorCount
    loop %count% {
        SysGet, screen, Monitor, %A_Index%
        display := {}
        display.width := screenRight - screenLeft 
        display.height := screenBottom - screenTop 
        display.x := screenLeft
        display.y := screenTop
        pos := {}
        pos.width := display.width * config.width_ratio * A_ScreenDPI/96
        pos.height := display.height * config.height_ratio * A_ScreenDPI/96
        pos.x := (display.width - pos.width) / 2 + display.x
        pos.y := screen.y

        display.pos := pos
        displays.Push(display) 
    }
}

GetDisplay(){
    static display := GetDisplays()

    If (active){
        For index, display in displays {
            CoordMode, Mouse, Screen
            MouseGetPos, x, y
            If (x <= display.x + display.width and y <= display.y + display.height)
                return display
        }
    } 
    return displays[0]
}

Activate(window) {

    SetWinDelay, 0
    WinShow, ahk_id %window%
    WinMove, ahk_id %window%,, % pos.x, -pos.height, pos.width, pos.height
    WinActivate, ahk_id %window%
    WinSet AlwaysOnTop, On, ahk_id %window% 
    WinSet, Transparent, Off, ahk_id %window% 
    y := -pos.height
    While, y < pos.y
        WinMove, ahk_id %window%,, % pos.x, y+=5, pos.width, pos.height
    WinMove, ahk_id %window%,, % pos.x, pos.y, pos.width, pos.height
}

Hide(window) {
    global ANIMATION_SPEED
    static pos := GetPosition()
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
    init := false
    if (!ProcessExists(pid)) {
        pid := StartApp(PATH, ARGS, PROC)
        PID(pid)
        WinWait, ahk_pid %pid%
        Sleep, 400
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

ExitFunction() {
    pid := PID()
    WinClose ahk_pid %pid%
}