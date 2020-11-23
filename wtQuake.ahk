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
    static ConfigPath := "wtQuake.json"

    /*
    * -----------------------------------------------
    * Class: Config
    * Represents the config file as an object.    
    * -----------------------------------------------
    */

    class Config {
        __New(configPath) {
            this.configPath := configPath
            this.config := this.Read(ConfigPath)
            if (ErrorLevel) {
                this.config := this.Init()
            }
            return this.config

        }
        __Delete() {
            this.Write()
        }

        Read() {
            ConfigFile := FileOpen(this.configPath, "r")

            if IsObject(ConfigFile) {
                ConfigStr := ConfigFile.Read()
                ConfigFile.Close()
                ErrorLevel := 0
                return JSON.Load( ConfigStr )
            } else { 
                ErrorLevel := 1
            }
        }

        Write(configOut) {
            configFile := FileOpen(this.configPath, "w")

            if IsObject(configFile) {
                configStr := JSON.Dump( configOut )
                configFile.Write(configStr)
                configFile.Close()
                ErrorLevel := 0
            } else {
                MsgBox % "Can't open " . this.configPath
                ErrorLevel := 1
            }
        }

        Init() {
            MsgBox, 0x10, "No config file found. Generating new wtQuake.json..."

            this.config := { path: "wt" , args: "-f", process: "WindowsTerminal.exe", heightRatio: 0
            , widthRatio: 0.5, autohide: 0.25, activeDisplay: 0, animSpeed: 5 }

            this.Write(this.config)
            return this.config
        }
    } 

    /*
    * -----------------------------------------------
    *   end Config
    * -----------------------------------------------
    */

    __New() {
        this.Init()
        this.hidden := true
    }

    __Delete() {
        this.Close()
    }

    Init() {
        this.config := new WTQuake.Config(WTQuake.ConfigPath)
        this.displays := this.InitDisplays()
        this.Launch()
        WinWait, % this.ahk_pid
        Sleep, 400
        if (!this.window) 
            MsgBox, 0x10, "Bad window", % "The process " this.config.process " (" this.pid ") doesn't have any windows."

        this.hidden := false
    }

    Launch() {
        prevPIDs := this.GetPIDs()
        Run % this.config.path . " " . this.config.args,,, runPID
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
        for aProc in wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" this.config.process "'")
            pids.Push(aProc.processId)

        return pids
    }

    ProcessExists() {
        Process, Exist, % this.pid
        return (ErrorLevel == this.pid)
    }

    InitDisplays() {
        dispArray := []
        SysGet, count, MonitorCount
        loop %count% {
            SysGet, screen, Monitor, %A_Index%
            display := {}
            display.width := screenRight - screenLeft 
            display.height := screenBottom - screenTop 
            display.x := screenLeft
            display.y := screenTop
            pos := {}
            pos.width := display.width * this.config.widthRatio * A_ScreenDPI/96
            pos.height := display.height * this.config.heightRatio * A_ScreenDPI/96
            pos.x := (display.width - pos.width) / 2 + display.x
            pos.y := display.y

            display.pos := pos
            dispArray.Push(display) 
        }
        return dispArray
    }

    Activate() {
        pos := this.position

        SetWinDelay, 0
        WinShow, % this.ahk_id
        WinMove, % this.ahk_id,, pos.x, -pos.height, pos.width, pos.height
        WinActivate, % this.ahk_id
        WinSet AlwaysOnTop, On, % this.ahk_id 
        WinSet, Transparent, Off, % this.ahk_id 
        If (this.config.animSpeed){
            y := -pos.height
            While, y < pos.y
                WinMove, % this.ahk_id,, pos.x, y+=this.config.animSpeed, pos.width, pos.height
        }
        WinMove, % this.ahk_id,, pos.x, pos.y, pos.width, pos.height
    }

    Hide() {
        pos := this.position

        SetWinDelay, 0
        If (this.config.animSpeed){
            y := pos.y
            While, y > -pos.height 
                WinMove, % this.ahk_id,, pos.x, y-=this.config.animSpeed, pos.width, pos.height
        }
        WinMove, % this.ahk_id,, pos.x, -pos.height, pos.width, pos.height
        WinSet AlwaysOnTop, Off, % this.ahk_id 
        WinSet, Transparent, 0, % this.ahk_id 
        WinMinimize, % this.ahk_id
        WinHide, % this.ahk_id
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
            If (this.config.activeDisplay){
                For index, display in this.displays {
                    CoordMode, Mouse, Screen
                    MouseGetPos, x, y
                    If (x <= display.x + display.width and y <= display.y + display.height)
                        return display.pos
                }
            } 
            return this.displays[1].pos
        }
    }

    window {
        get {
            WinGet, windows, List, % this.ahk_pid
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

    id {
        get {
            return this._id
        }
        set {
            this._id := value
            this.ahk_id := "ahk_id" . value
            return value
        }
    }

    pid {
        get {
            return this._pid
        }
        set {
            this._pid := value
            this.ahk_pid := "ahk_pid" . value
            return value
        }
    }
}
ExitFunction() {
    wtQuake.Close()
}