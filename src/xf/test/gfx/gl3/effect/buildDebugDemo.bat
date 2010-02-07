@del .deps
@del Main.exe
xfbuild +threads1 -g -version=StackTracing -version=Demo -version=DogCgNoErrorChecking -d Main.d ../../../../utils/impl/ +oMain +xtango -I../../../../..
@pause
