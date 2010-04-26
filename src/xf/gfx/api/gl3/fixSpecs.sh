cat gl.tm | sed -e '/String,/s/GLubyte/GLchar/' > gl.tm.1
mv gl.tm.1 gl.tm
