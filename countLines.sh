hg locate -I src/xf -I src/hsfexp -I src/scintilla/dee \
| grep \
	-e '\.d$' \
	-e '\.di$' \
	-e '\.cpp$' \
	-e '\.cxx$' \
	-e '\.c$' \
	-e '\.h$' \
	-e '\.hpp$' \
	-e '\.hxx$' \
	-e '\.py$' \
	-e '\.cfg$' \
	-e '\.bat$' \
	-e '\.lst$' \
	\
| grep -v \
	-e 'gl3/cgfx/.*\.h' \
	-e 'gl3/cgfx/.*\.cg' \
	-e 'src/xf/platform'\
   	-e 'xf/input/KeySym\.d' \
	\
| xargs wc -l
