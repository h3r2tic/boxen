xfbuild -release -inline -O +R +nolink +Olibobjs +xtango +nodeps ./ -I../../../
bash -c 'lib.exe -p032 -c omgCore.lib libobjs/*.obj'
rm -Rf .deps libobjs/
