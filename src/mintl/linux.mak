
# To build libmintl.a type
#  make -f linux.mak DFLAGS=-g LIBNAME=libmintl_debug.a
# or
#  make -f linux.mak DFLAGS=-release LIBNAME=libmintl.a
# The libmintl.a and object files will be created in the source directory.

# flags to use building unittest.exe
DUNITFLAGS=-g -unittest -I.. -version=MinTLUnittest -version=MinTLVerboseUnittest

# flags to use when building the mintl.lib library
DLIBFLAGS=$(DFLAGS) -I..
#DLIBFLAGS=-g -I..

DMD=dmd

#LIBNAME = libmintl.a

targets : unittest

mintl : $(LIBNAME)

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

OBJS = all.o  \
	array.o \
	arraylist.o \
	arrayheap.o \
	deque.o \
	hashaa.o \
	list.o \
	slist.o \
	share.o \
	adapter.o \
	stack.o \
	queue.o \
	set.o \
	multiaa.o \
	mem.o \
	sorting.o \
	sortedaa.o

$(LIBNAME) : $(OBJS) $(SRC)
	ar -r $@ $(OBJS)

clean:
	rm *.o 
	rm $(LIBNAME)
	rm unittest

%.o : %.d
	$(DMD) -c $(DLIBFLAGS) $< -of$@

unittest : $(LIBNAME) $(OBJS) $(SRC)
	$(DMD) $(DUNITFLAGS) unittest.d -ofunittest $(SRC)

