# We don't want to follow any imports

sed -e 's/#include.*//' FreeImage.h > FreeImageNoImp.h

# --- Preprocess ---

cpp -x c++ -o FreeImageNoImpPP.h FreeImageNoImp.h

rm FreeImageNoImp.h

# The header is Latin-1 and has some regional chars. D wants Unicode

cat FreeImage.h | sed \
-ne '1,/\/\/ =/p' \
| iconv -f iso-8859-1 -t utf-8 \
> FreeImage.almost.d

printf '\n// Header converted to D by Tomasz Stachowiak\n\nmodule freeimage.FreeImage;\n\n' >> FreeImage.almost.d

# ---- Convert the C(++) declarations to D ----

cat FreeImageNoImpPP.h | sed \
-e '/^#pragma pack(push, 1)/,/#pragma pack(pop)/ s/struct \([a-zA-Z_][a-zA-Z_0-9]*\) {/struct \1 {\
align(1):/' \
| sed \
-e 's/__attribute__((dllimport))//g' \
-e 's/__attribute__((__stdcall__))//g' \
-e '/^# .*/d' \
-e 's/\<typedef struct\>/struct/g' \
-e 's/^}.*;[ ^I]*$/}/' \
-e 's/typedef/alias/g' \
-e 's/struct tag\([a-zA-Z_][a-zA-Z_0-9]*\)[ ^I]*{/struct \1{/g' \
-e 's/\<const\>//g' \
-e 's/enum \([a-zA-Z_][a-zA-Z_0-9]*\)/typedef int \1; enum : \1/g' \
| sed \
-e '/^#pragma.*/d' \
-e 's/^extern "C" {$/extern (System) {/' \
| sed \
-e 's/\<int8_t\>/byte/g' \
-e 's/\<int16_t\>/short/g' \
-e 's/\<int32_t\>/int/g' \
-e 's/\<uint8_t\>/ubyte/g' \
-e 's/\<uint16_t\>/ushort/g' \
-e 's/\<uint32_t\>/uint/g' \
-e 's/\<unsigned[ ^I][ ^I]*int\>/int/g' \
-e 's/\<unsigned[ ^I][ ^I]*long\>/size_t/g' \
-e 's/\<long\>/ptrdiff_t/g' \
-e 's/\<unsigned\>/uint/g' \
-e 's/\<wchar_t\>/wchar/g' \
-e 's/(void)/()/g' \
-e 's/\(\*[^,]*\)=[ ^I]*0/\1= null/g' \
| sed \
-e 's/^alias \([^(]*\)([ ^I]*\*[ ^I]*\([a-zA-Z_][a-zA-Z_0-9]*\)[ ^I]*)[ ^I]*(\([^)]*\));$/extern (System) alias \1 function(\3) \2;/' \
| cat -s \
>> FreeImage.almost.d

rm FreeImageNoImpPP.h

matchFunc='^[ ^I]*\([a-zA-Z_][a-zA-Z_0-9]*[ *^I]*\)\([a-zA-Z_][a-zA-Z_0-9]*\)(\(.*\));$'

# ---- Convert function prototypes to the D style ----

# Using varargs will force the C calling convention

cat FreeImage.almost.d | sed \
-e "s/$matchFunc/\1 function(\3) \2;/" \
-e 's/^[ ^I]*extern (System)\(.*\)\.\.\./extern (C) \1.../' \
-e 's/^[ ^I]*\(.*\)\.\.\./extern (C) \1.../' \
-e 's/extern (C)[ ^I]*extern (C)[ ^I]*/extern (C) /' \
> FreeImage.d

rm FreeImage.almost.d

# ---- Create the loader ----

cat FreeImageLoader.d.prefix > FreeImageLoader.d

# Extract function symbol names directly from the DLL because they use
# the Windows name mangling scheme

implib FreeImage.lib FreeImage.dll
lib -l FreeImage.lib
rm FreeImage.lib

# Iterate all symbols and create loading code for them

for sym in `cat FreeImage.lst \
| sed -ne '3,/^$/p' \
| cut -f1 -d' '`
do
	funcName=`echo $sym | cut -f1 -d'@' | sed -e 's/^_//'`
	echo "		loadSymbol(cast(void**)&$funcName, \"$sym\");" >> FreeImageLoader.d
done
rm FreeImage.lst

# Finally write the suffix of the loader

cat FreeImageLoader.d.suffix >> FreeImageLoader.d

