' ============================================================
'  Taller en Vivo 2.0 - lanzador sin ventanas
'  1. Arranca el servidor (backend\servidor.py) oculto. Si ya estaba abierto, el segundo se cierra solo.
'  2. Abre el programa en una ventana propia de Microsoft Edge.
'  Requiere MySQL 8 encendido y la instalacion de README.md.
' ============================================================
Option Explicit
Dim sh, fso, dir, py
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName) & "\backend"
py = dir & "\.venv\Scripts\pythonw.exe"
If Not fso.FileExists(py) Then
  MsgBox "Falta instalar el entorno de Python. Sigue los pasos de README.md.", vbExclamation, "Taller en Vivo"
  WScript.Quit 1
End If
sh.CurrentDirectory = dir
sh.Run """" & py & """ """ & dir & "\servidor.py""", 0, False
WScript.Sleep 2500
sh.Run "msedge --app=http://localhost:5517/", 1, False
