import urllib.request
import os
if os.path.exists("s"):
    os.remove("s")
f = open("s", "x")
f.write(str(urllib.request.urlopen("https://growtopiagame.com/Growtopia-Installer.exe").length))
f.close()