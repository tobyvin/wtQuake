#NoEnv
#Warn
#SingleInstance, Force
#NoTrayIcon
#MaxThreadsPerHotkey 2
#Include <JSON>

SendMode Input
DetectHiddenWindows, On
OnExit("ExitFunction")

wt := new wtQuake()

#`::wt.Toggle()

class WTQuake
{
    static ConfigPath := wtQuake.json

    __New() {
        this.Init()
    }

    __Delete() {
        this.Close()
    }

    class Config {
        __New(ConfigPath) {
            this.ConfigPath := ConfigPath
            this.ConfigRead()
            if (ErrorLevel) {
                this.Init()
            }
            return this

        }
        __Delete() {
            this.ConfigWrite()
        }

        Read() {
            ConfigFile := FileOpen(this.ConfigPath, "r")

            if IsObject(ConfigFile) {
                ConfigStr := ConfigFile.Read()
                ConfigFile.Close()
                ErrorLevel := 0
                return JSON.Load( ConfigStr )
            } else { 
                ErrorLevel := 1
            }
        }

        Write(ConfigOut) {
            ConfigFile := FileOpen(this.ConfigPath, "w")

            if IsObject(ConfigFile) {
                ConfigStr := JSON.Dump( ConfigOut )
                ConfigFile.Write(ConfigStr)
                ConfigFile.Close()
                ErrorLevel := 0
            } else {
                MsgBox % "Can't open " . this.ConfigPath
                ErrorLevel := 1
            }
        }

        Init() {
            this.Config := { path: "wt" , args: "-f", process: "WindowsTerminal.exe", heightRatio: 0
            , widthRatio: 0.5, autohide: 0.25, activeDisplay: 0, animSpeed: 5 }

            this.Write(this.Config)
        }

        __Get(aName) {
            aValue := this.Config[aName]
            if (aValue)
                return this.Config[aName]
            return this.Read()[aName]
        }
        __Set(aName, aValue) {
            this.Config[aName] := aValue
            this.ConfigWrite(this.Config)
        }

    }

    Init() {
        this.Config := new Config(WTQuake.ConfigPath)
        this.displays := this.CalcDisplays()
        this.Start()
        WinWait, this.ahk_pid
        Sleep, 400
        this.hidden := false
    }

    Start() {
        prevPIDs := this.GetPIDs(this.Config.procName)
        Run % this.Config.path . " " . this.Config.args,,, runPID
        this.pid := runPID
        if (this.pid) {
            return 
        }

        newPIDs := this.GetPIDs()
        Sort, prevPIDs
        Sort, newPIDs

        for idx, newPID in newPIDs {
            if (newPID != prevPIDs[idx]) {
                this.pid := newPID
                return
            }
        }
    }

    GetPIDs() {
        static wmi := ComObjGet("winmgmts:root\cimv2")

        pids := []
        for aProc in wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" this.Config.procName "'")
            pids.Push(aProc.processId)

        return pids
    }

    ProcessExists(pid) {
        Process, Exist, this.ahk_pid
        return (ErrorLevel == pid)
    }

    CalcDisplays() {
        this.displays[]
        SysGet, count, MonitorCount
        loop %count% {
            SysGet, screen, Monitor, %A_Index%
            display := {}
            display.width := screenRight - screenLeft 
            display.height := screenBottom - screenTop 
            display.x := screenLeft
            display.y := screenTop
            pos := {}
            pos.width := display.width * this.Config.width_ratio * A_ScreenDPI/96
            pos.height := display.height * this.Config.height_ratio * A_ScreenDPI/96
            pos.x := (display.width - pos.width) / 2 + display.x
            pos.y := screen.y

            display.pos := pos
            this.displays.Push(display) 
        }
    }

    Activate() {
        pos := this.position

        SetWinDelay, 0
        WinShow, this.ahk_id
        WinMove, this.ahk_id,, % pos.x, -pos.height, pos.width, pos.height
        WinActivate, this.ahk_id
        WinSet AlwaysOnTop, On, this.ahk_id 
        WinSet, Transparent, Off, this.ahk_id 
        y := -pos.height
        While, y < pos.y
            WinMove, this.ahk_id,, % pos.x, y+=5, pos.width, pos.height
        WinMove, this.ahk_id,, % pos.x, pos.y, pos.width, pos.height
    }

    Hide() {
        pos := this.position

        SetWinDelay, 0
        If (this.Config.animSpeed){
            While, pos.y > -pos.height 
                WinMove, this.ahk_id,, % pos.x, pos.y-=this.Config.animSpeed, pos.width, pos.height
        }
        WinSet AlwaysOnTop, Off, this.ahk_id 
        WinSet, Transparent, 0, this.ahk_id 
        WinMinimize, this.ahk_id
        WinHide, this.ahk_id
    }

    Toggle() {
        if (!this.ProcessExists()) {
            this.Init()
        } else if (this.window) {
            this.hidden := !this.hidden
        }
    }

    Close() {
        WinClose, % this.ahk_pid
        this.pid := this.id := ""
    }

    position {
        get {
            If (this.Config.activeDisplay){
                For index, display in this.displays {
                    CoordMode, Mouse, Screen
                    MouseGetPos, x, y
                    If (x <= display.x + display.width and y <= display.y + display.height)
                        return display.pos
                }
            } 
            return displays[0].pos
        }
    }

    window {
        get {
            WinGet, windows, List, this.ahk_pid
            this.id := windows ? windows1 : 0
            return this.id
        }
    }

    hidden[] {
        get {
            DetectHiddenWindows, Off
            isHidden := WinExist(this.ahk_id)
            DetectHiddenWindows, On
            if isHidden
                return false
            return true
        }
        set {
            if (value)
                this.Hide()
            else
                this.Activate()
        }
    }

    ahk_id[] {
        get {
            return "ahk_id " . this.id
        }
    }

    ahk_pid [] {
        get {
            return "ahk_pid " . this.pid
        }
    }
}
ExitFunction() {
    wtQuake.Close()
}