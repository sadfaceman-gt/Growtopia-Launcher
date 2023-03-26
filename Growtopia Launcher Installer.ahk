#Requires AutoHotkey v2-
SetWorkingDir A_ScriptDir
#SingleInstance Ignore
DetectHiddenWindows True

If !FileExist(A_WorkingDir . "\data"){
    MsgBox("Extract the installer from the zip file first", "Growtopia Launcher Installer", "OK T5")
    ExitApp
}
GTDir := EnvGet("LocalAppData") . "\Growtopia"
If !FileExist(GTDir . "\Growtopia.exe"){
	MsgBox "Couldn't find Growtopia install location. Please select the folder where Growtopia is installed", "Growtopia Launcher Installer", "OK T10"
    SelectGTDir()
}
If FileExist(GTDir . "\Growtopia.exe"){
    MsgBoxRes := MsgBox(GTDir . "`nInstall Growtopia Launcher here?", "Growtopia Launcher Installer", "YesNoCancel T15")
    If MsgBoxRes = "No"
		SelectGTDir()
    If MsgBoxRes = "Cancel" {
        MsgBox "Installation cancelled", "Growtopia Launcher Installer", "OK T5"
        ExitApp
    }
}
While !FileExist(GTDir . "\Growtopia.exe"){
    If !GTDir or (MsgBox("Couldn't find a Growtopia.exe executable. Install here anyway?", "Growtopia Launcher Installer", "OK T10") = "No")
		SelectGTDir()
	Else
		Break
}
If WinExist("ahk_exe AutoHotkey64.exe ahk_class AutoHotkeyGUI") or WinExist("ahk_exe growtopia.exe ahk_class AppClass"){
	MsgBox "Close Growtopia and Growtopia Launcher first!", "Growtopia Launcher Installer", "OK T5"
	ExitApp
}
If FileExist(GTDir . "\.launcher")
	DirDelete GTDir . "\.launcher"
If FileExist(GTDir . "\Launcher"){
    Upgrade()
    MsgBox "Successfully updated Growtopia Launcher", "Growtopia Launcher Installer", "OK T5"
    ExitApp
}
Install()
MsgBox "Successfully installed Growtopia Launcher", "Growtopia Launcher Installer", "OK T5"
If FileExist(GTDir . "\Growtopia Launcher.exe")
    Run GTDir . "\Growtopia Launcher.exe"
ExitApp

SelectGTDir(){
    Global
    GTDir := FileSelect("D", EnvGet("LocalAppData"), "Select your Growtopia installation folder")
	Return
}

Upgrade(){
	Global
    Loop Files GTDir . "\*.*" {
        If InStr(A_LoopFileName, "Growtopia Launcher")
            FileDelete A_LoopFilePath
    }
    Loop Files GTDir . "\Launcher\*", "FR" {
        If A_LoopFileName = "Settings" {
            If(MsgBox("Reset settings to default values? Recommended if the update adds a new setting", "Growtopia Launcher Installer", "YesNo T10") = "No")
                Continue
            If A_LoopFileName = "g"
                Continue
            FileDelete A_LoopFilePath
        }
    }
    Install()
}

Install(){
	Global
    DirCopy A_WorkingDir . "\data", GTDir, 1
    Loop Files GTDir . "\*.ahk" {
        If InStr(A_LoopFileName, "Growtopia Launcher")
            ExeName := A_LoopFileName
    }
    RunWait A_ComSpec ' /c ahk2exe /in "' . GTDir . '\' . ExeName . '" /out "' . GTDir . '\Growtopia Launcher.exe" /base "AutoHotkeyUX.exe" /icon "' . GTDir . '\Launcher\Images\logo.ico" /silent', GTDir . "\Launcher\Bin\", "Min"
    If !FileExist(GTDir . "\Growtopia Launcher.exe"){
        MsgBox "Failed to compile " . ExeName, "Growtopia Launcher Installer", "OK T5"
        Return
    }
    FileCreateShortcut GTDir . "\Growtopia Launcher.exe", A_Desktop . "\Growtopia Launcher.lnk", , "Open Growtopia Launcher", GTDir . "\Launcher\Images\logo.ico"
    Return
}