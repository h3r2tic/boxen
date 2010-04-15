del *.dot *.png *.exe
call build
if exist Main.exe Main.exe
@call dotAndView g2.dot
@call dotAndView g2b.dot
@call dotAndView g2c.dot
@call dotAndView g2d.dot

