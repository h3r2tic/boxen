
# To build mintl.lib type 
#  make -f win32.mak DFLAGS=-g LIBNAME=mintl_debug.lib
# or
#  make -f win32.mak DFLAGS=-release LIBNAME=mintl.lib
# The mintl.lib and object files will be created in the source directory.

# flags to use building unittest.exe
DUNITFLAGS=-g -v -unittest -I.. -version=MinTLUnittest -version=MinTLVerboseUnittest

# flags to use when building the mintl.lib library
DLIBFLAGS=$(DFLAGS) -release -I..

DMD = dmd
LIB = lib

targets : unittest

unittest : unittest.exe

LIBNAME = mintl.lib

#mintl : $(LIBNAME)

SRC = all.d \
	array.d \
	arraylist.d \
	arrayheap.d \
	deque.d \
	hashaa.d \
	list.d \
	slist.d \
	share.d \
	adapter.d \
	stack.d \
	queue.d \
	set.d \
	multiaa.d \
	mem.d \
	sorting.d \
	sortedaa.d 

OBJS = all.obj \
	array.obj \
	arraylist.obj \
	arrayheap.obj \
	deque.obj \
	hashaa.obj \
	list.obj \
	slist.obj \
	share.obj \
	adapter.obj \
	stack.obj \
	queue.obj \
	set.obj \
	multiaa.obj \
	mem.obj \
	sorting.obj \
	sortedaa.obj

.d.obj :
	$(DMD) -c $(DLIBFLAGS) -of$@ $<

$(LIBNAME) : $(OBJS) $(SRC)
	$(LIB) -c $@ $(OBJS)


unittest.exe : $(LIBNAME) $(SRC)
	$(DMD) $(DUNITFLAGS) unittest.d -ofunittest.exe $(SRC)

clean:
	del *.obj
	del $(LIBNAME)
	IF EXIST unittest.exe del unittest.exe
