enki.exe KDefLexer.bnf
if not %errorlevel%==0 goto poop
enki.exe KDefParser.bnf
if not %errorlevel%==0 goto poop
:poop
pause
