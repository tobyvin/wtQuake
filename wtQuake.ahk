#NoEnv
#SingleInstance, Force
#NoTrayIcon
#MaxThreadsPerHotkey 2

SendMode Input
DetectHiddenWindows, On
OnExit("ExitFunction")

#`::ToggleApp()

StartApp(cfg) {
    prevPIDs := GetPIDs(cfg.procName)
    Run % cfg.path . " " . cfg.args,,, pid

    if (pid) {
        return pid
    }

    newPIDs := GetPIDs(cfg.procName)
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
    IniRead, path, wtQuake.ini, WindowsTerminal, path, "wt"
    IniRead, args, wtQuake.ini, WindowsTerminal, args, "-f"
    IniRead, proc, wtQuake.ini, WindowsTerminal, process, "WindowsTerminal.exe"
    IniRead, active_display, wtQuake.ini, Window, active_display, 0
    IniRead, width_ratio, wtQuake.ini, Window, width_ratio, 0.5
    IniRead, height_ratio, wtQuake.ini, Window, height_ratio, 0.25
    IniRead, autohide, wtQuake.ini, Window, autohide, 0
    IniRead, animation_speed, wtQuake.ini, Window, animation_speed, 5

    return { path: path
        , args: args
        , proc: proc
        , active_display: active_display
        , width_ratio: width_ratio
        , height_ratio: height_ratio
        , autohide: autohide
    , animation_speed: animation_speed }
}

GetDisplays(cfg) {
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
        pos.width := display.width * cfg.width_ratio * A_ScreenDPI/96
        pos.height := display.height * cfg.height_ratio * A_ScreenDPI/96
        pos.x := (display.width - pos.width) / 2 + display.x
        pos.y := screen.y

        display.pos := pos
        displays.Push(display) 
    }
}

GetPosition(displays){
    If (active){
        For index, display in displays {
            CoordMode, Mouse, Screen
            MouseGetPos, x, y
            If (x <= display.x + display.width and y <= display.y + display.height)
                return display.pos
        }
    } 
    return displays[0].pos
}

Activate(window) {
    pos := GetPosition(window.displays)

    SetWinDelay, 0
    WinShow, % "ahk_id" . window.id
    WinMove, % "ahk_id" . window.id,, % pos.x, -pos.height, pos.width, pos.height
    WinActivate, % "ahk_id" . window.id
    WinSet AlwaysOnTop, On, % "ahk_id" . window.id 
    WinSet, Transparent, Off, % "ahk_id" . window.id 
    y := -pos.height
    While, y < pos.y
        WinMove, % "ahk_id" . window.id,, % pos.x, y+=5, pos.width, pos.height
    WinMove, % "ahk_id" . window.id,, % pos.x, pos.y, pos.width, pos.height
}

Hide(window) {
    pos := GetPosition(window.displays)

    SetWinDelay, 0
    If (window.cfg.animation_speed){
        While, pos.y > -pos.height 
            WinMove, % "ahk_id" . window.id,, % pos.x, pos.y-=window.cfg.animation_speed, pos.width, pos.height
    }
    WinSet AlwaysOnTop, Off, % "ahk_id" . window.id 
    WinSet, Transparent, 0, % "ahk_id" . window.id 
    WinMinimize, % "ahk_id" . window.id
    WinHide, ahk_id %window%
}

IsActive(window) {
    IfWinActive, % "ahk_id" . window.id
        return true
    return false
}

IsHidden(window) {
    DetectHiddenWindows, Off
    if WinExist("ahk_id" . window.id)
        return false
    return true
}

GetWindow(pid) {
    WinGet, windows, List, ahk_pid %pid%
    return windows ? windows1 : 0
}

ToggleApp(getPID:=0) {
    static window := {}
    ; static pid := ""
    ; cfg := GetConfig()
    ; pid := ""
    if (exiting)
        return 
    init := false
    if (!ProcessExists(window.pid)) {
        window.cfg := GetConfig()
        window.displays := GetDisplays(window.cfg)
        window.pid := StartApp(window.cfg)
        WinWait, % "ahk_pid" . window.pid
        Sleep, 400
        init := true
    }
    ; window.cfg := cfg
    window.id := GetWindow(window.pid)
    if (window.id) {
        if ( init || IsHidden(window) )
            Activate(window)
        else 
            Hide(window)

    } else {
        MsgBox, 0x10, "Bad window", % "The process " window.cfg.proc " (" pid ") doesn't have any windows."
        pid := ""
    }
}

ExitFunction() {
    ToggleApp(1)
    WinClose, % "ahk_pid" . window.pid
}