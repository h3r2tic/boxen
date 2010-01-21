@del .deps
@del Main.exe
xfbuild +threads1 -version=Demo -version=Release -version=DogCgNoErrorChecking -d Main.d ../../../../utils/impl/ +oMain +xtango -inline -release -O -I../../../../..
@pause
