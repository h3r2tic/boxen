del Main.exe
xfbuild -version=StackTracing -d Main.d ../../../utils/impl/ ../../../net/enet/ enet.lib +oMain +xtango -g -I../../../..
start Main.exe server
start Main.exe client
@pause
