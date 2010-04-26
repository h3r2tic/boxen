apaged Config.apd Config.d
rem the scope(exit) upsets LDC, but we don't need it anyway
sed -e "s/typeof(WhitespaceGrammar)/WhitespaceGrammar/" -e "s/.*scope(exit) debug(parser).*//g" -e "s/bool isErrorSynced(uint state);/abstract bool isErrorSynced(uint state);/g" -e "s/uint\[\] lookaheadForNT(uint nt_index, uint state);/abstract uint[] lookaheadForNT(uint nt_index, uint state);/g" Config.d >Config.sed.d
mv Config.sed.d Config.d
pause
