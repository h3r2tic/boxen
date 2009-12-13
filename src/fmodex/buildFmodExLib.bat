echo ---- Setting env vars ----
call %VCToolkitInstallDir%\vcvars32.bat
set INCLUDE=%INCLUDE%;inc

echo ---- Compiling FmodEx DLLs ----
cl FmodExCore.cpp fmodex_vc.lib /LD /EHsc /DWIN32 /wd4190 /link/nologo /nologo
copy FmodExCore.dll ..\tests\fmod\
move FmodExCore.dll .. >NUL
move FmodExCore.lib .. >NUL
del FmodExCore.exp
del FmodExCore.obj

pause