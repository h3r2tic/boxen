xfbuild -version=Server +D.s.deps +O.s.objs -version=StackTracing -d Main.d ../../../utils/impl/ ../../../net/enet/ +oServer +xtango -g -I../../../..
xfbuild -version=Client +D.c.deps +O.c.objs -version=StackTracing -d Main.d ../../../utils/impl/ ../../../net/enet/ +oClient +xtango -g -I../../../..
