URL := "SomeSite.com"
Target := "SiteFile.txt"
FDir := A_WorkingDir

FileAppend 'Try`n`tDownload "' . URL . '", "' . Target . '"`nCatch`n`tFileDelete "' . Target . '"`nExitApp', FDir . "\Downloader.ahk"