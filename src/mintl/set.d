/** \file set.d
 * \brief Set, sorted set and multi-set containers.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.7.1
 */

module xf.mintl.set;
static assert(false, "TODO"); //TODO
/+
private import xf.mintl.share;
private import xf.mintl.adapter;
private import xf.mintl.sortedaa;
private import xf.mintl.hashaa;
private import std.stdarg;
private import std.boxer;

//version = WithBox;

template MAddSet(Container,Value) {
  /** Inserts the specified items into the set.   */
  void add(...) {
    vadd(_arguments,_argptr);
  }
  void vadd(TypeInfo[] arguments, void* argptr) {
    for (int k=0;k<arguments.length;k++) {
      TypeInfo tik = typeid(Value);
      if (arguments[k] == tik) {
	addItem(va_arg!(Value)(argptr));
      } else {
	version(WithBox) {
	Box b = box(tik,argptr);
        addItem(unbox!(Value)(b));
	argptr += va_argumentLength(tik.tsize());
	}
      }
    }
  }
  /** Construct a container with specified contents */
  static Container make(...) {
    Container res;
    res.vadd(_arguments,_argptr);
    return res;
  }
}

/** A set of items. By default the backing container is a HashAA
 * associative array.
 */
struct Set(Value, ImplType = HashAA!(Value,uint)) {

  alias Set         ContainerType;
  alias Value       ValueType;
  alias ImplType    AdaptType;
  const bit isReadOnly = ImplType.isReadOnly;

  ImplType impl;

  mixin MAdaptBuiltin!(impl,Set);
  static if (!ImplType.isReadOnly) {
  void remove(Value item) { impl.remove(item); }
  }
  bool opIndex(Value item) {return impl.contains(item); }
  Set dup() {
    Set res;
    res.impl = impl.dup;
    return res;
  }
  void clear(){ impl.clear(); }
  bool isEmpty() { return impl.isEmpty(); }
  static if (!ImplType.isReadOnly) {
    mixin MAddSet!(Set,Value) mAdd;
  }

  Value[] values() { return impl.keys; }
  void addItem(Value item) { impl[item] = 1; }
  int opApply(int delegate(inout Value x) dg){
    int res;
    foreach(Value item, uint ignore; impl) {
      res = dg(item);
      if (res) break;
    }
    return res;
  }
}

/** Adapter for sorted set of items. */
template SortedSet(Value) {
  alias Set!(Value,SortedAA!(Value,uint)) SortedSet;
}

/** A set of items with repeats. By default the backing container is a 
 * HashAA associative array.
 */
struct MultiSet(Value, ImplType = HashAA!(Value,uint)) {

  alias Set         ContainerType;
  alias Value       ValueType;
  alias ImplType    AdaptType;
  static if (is(ImplType:uint[Value])) {
    const bit isReadOnly = false;
  } else {
    const bit isReadOnly = ImplType.isReadOnly;
  }

  ImplType impl;

  size_t length() {
    size_t total = 0;
    foreach(uint val; impl) {
      total += val;
    }
    return total;
  }
  int opEquals(MultiSet c) { return impl == c.impl; }
  static if (!ImplType.isReadOnly) {
  void remove(Value item) { 
    uint* val = impl.get(item);
    if (val && (--(*val) == 0))
      impl.remove(item);
  }
  void addItem(Value item) { 
    (*impl.put(item))++;
  }
  }
  bool opIndex(Value item) {return impl.get(item) !is null; }
  MultiSet dup() {
    MultiSet res;
    res.impl = impl.dup;
    return res;
  }
  void clear(){ impl.clear(); }
  bool isEmpty() { return impl.isEmpty(); }
  static if (!ImplType.isReadOnly) {
    mixin MAddSet!(MultiSet, Value) mAdd;
  }

  Value[] values() { return impl.keys; }
  int opApply(int delegate(inout Value x) dg){
    int res;
    foreach(Value item, uint val; impl) {
      while (val--) {
	res = dg(item);
	if (res) break;
      }
    }
    return res;
  }
}

/** Adapter for sorted multi-set. */
template SortedMultiSet(Value) {
  alias MultiSet!(Value,SortedAA!(Value,uint)) SortedMultiSet;
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;
version (MinTLUnittest) {
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.set unittest\n");

    // test Set
    Set!(char[]) s;
    s.add("hello","world");
    assert( s["world"]  );
    assert( s["hello"]  );
    assert( !s["worldfoo"] );
    foreach(char[] val ; s) {
      version (MinTLVerboseUnittest) 
	printf("%.*s\n",val);
    }

    // test SortedSet
    SortedSet!(char[]) s2;
    s2.add("hello","world");
    assert( s2["world"]  );
    assert( s2["hello"]  );
    assert( !s2["worldfoo"] );
    foreach(char[] val ; s2) {
      version (MinTLVerboseUnittest) 
	printf("%.*s\n",val);
    }
    assert( !s2.isEmpty );

    // test MultiSet
    MultiSet!(int) ma2;
    ma2.add(22,-100,22);
    assert( ma2[22] );
    assert( ma2[-100] );
    int count22;
    int count;
    foreach( int item; ma2 ) {
      if (item == 22) {
	count22++;
      } else {
	count++;
      }
    }
    assert( count22 == 2 );
    assert( count == 1 );
    ma2.remove(-100);
    assert( ma2.length == 2 );
    ma2.remove(22);
    assert( ma2[22] );
    assert( ma2.length == 1 );
    ma2.remove(22);
    assert( ma2.length == 0 );
    assert( ma2.isEmpty );

    // test SortedMultiSet
    SortedMultiSet!(char[]) s3;
    s3.add("hello","world");
    assert( s3["world"]  );
    assert( s3["hello"]  );
    assert( !s3["worldfoo"] );

    version (MinTLVerboseUnittest) 
      printf("finished mintl.set unittest\n");
  }
}
+/