@del .deps
@del Main.exe
xfbuild +threads1 -version=Release -version=StackTracing -version=DogCgNoErrorChecking -d Main.d ../../../../utils/impl/ +oMain +xtango -inline -release -O -g -I../../../../.. && Main
@pause
