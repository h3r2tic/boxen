cd ../..
bash -login buildScintilla.sh
cd demos/scintilla
rebuild -I../../../.. -version=OldDogInput  -I../../../ext -J. Scintilla
cp ../../SciLexer.dll ./
pause
