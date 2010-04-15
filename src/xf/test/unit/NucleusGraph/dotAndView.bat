if exist %1 cat %1 | dot -Tpng -o %1.png -Gsize="28,28" -Gsep=.05
if exist %1 %1.png
