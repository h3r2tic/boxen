@echo off
if exist %1 cat %1 | C:\prog\graphviz\bin\dot -Tpng -o %1.png
if exist %1 %1.png
