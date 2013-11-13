@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\..\coffee-script\bin\coffee"  "%~dp0\..\..\src\command.coffee" %*
) ELSE (
  node  "%~dp0\..\coffee-script\bin\coffee"  "%~dp0\..\..\src\command.coffee" %*
)
