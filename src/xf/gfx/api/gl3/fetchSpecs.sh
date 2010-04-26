files=(\
	gl.spec \
	gl.tm \
	enum.spec \
	wgl.spec \
	wgl.tm \
	wglenum.spec \
	wglenumext.spec \
	wglext.spec \
)

specBaseURL="http://www.opengl.org/registry/api/"

if [ -d specFiles ] ; then rm -Rf specfiles ; fi
mkdir specFiles
cd specFiles

for f in ${files[*]}
do
	if ! wget "${specBaseURL}${f}"
	then
		echo Could not fetch spec file $f
		exit
	fi
done

cd ..

echo Got spec files

for f in ${files[*]}
do
	rm $f
	mv specFiles/$f $f
done

rmdir specFiles


./fixSpecs.sh
