xfbuild -release -inline -O +R +nolink +Olibobjs +xtango +nodeps gl3/ -I../../../
bash -c 'lib.exe -p032 -c gl3.lib libobjs/*.obj'
rm -Rf .deps libobjs/
