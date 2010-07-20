xfRedimple.exe Main -f"Main.deps" -lr -xhybrid -xomg -xmintl -xutils -xgl3 -xxf.mem -xplatform -xinput -xloader -xenki -xstd -xxf.core -xxf.gfx -xxf.img -xxf.Common >redimpleImports.txt
cat redimpleImports.txt | C:\prog\graphviz\bin\dot -Kdot -Tpng -o redimple.png -Gsep=.05 -Gsize="40,40"
pause
