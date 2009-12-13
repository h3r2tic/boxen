/** \file multiaa.d
 * \brief An associative array that allows multiple values per key.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * The red-black tree code is by Thomas Niemann.
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 1.2
 */

module mintl.multiaa;
static assert(false, "TODO"); //TODO
/+
private import mintl.share;
private import mintl.adapter;
private import mintl.sortedaa;
private import mintl.hashaa;
private import std.stdarg;
private import std.boxer;

//version = WithBox;

/** An associative array of items with duplicate keys. 
 * By default the backing container is a builtin associative array.
 */
struct MultiAA(Key, Value, ImplType = HashAA!(Key,Value[])) {

  alias MultiAA     ContainerType;
  alias Value       ValueType;
  alias Key         IndexType;
  alias ImplType    AdaptType;
  const bit isReadOnly = ImplType.isReadOnly;

  ImplType impl;

  size_t length() {
    size_t total = 0;
    foreach(Value[] val; impl) {
      total += val.length;
    }
    return total;
  }
  int opEquals(MultiAA c) { return impl == c.impl; }
  static if (!ImplType.isReadOnly) {
  void remove(Key key) { 
    impl.remove(key);
  }
  void remove(Key key, Value val) { 
    Value[]* vals = impl.get(key);
    if (vals) {
      size_t k;
      Value[] x = *vals;
      for(k = 0; k<x.length;k++) {
	if (x[k] == val) 
	  break;
      }
      for(; k < x.length-1; k++) {
	x[k] = x[k+1];
      }
      *vals = x[0 .. k];
    }
  }
  void addItem(Key key, Value item) { 
    Value[]* vals = impl.put(key);
    (*vals) ~= item;
  }
  void clear(){ impl.clear(); }
  } // !isReadOnly
  Value[] opIndex(Key key) {return impl[key];}
  MultiAA dup() {
    MultiAA res;
    res.impl = impl.dup;
    return res;
  }
  bool isEmpty() { return impl.isEmpty(); }
  //  mixin MMAASpecial!(impl,MultiAA,Key,Value,ImplType) mAA;
  static if (!ImplType.isReadOnly) {
  /** Inserts the specified items into the target AA by calling
   * x[key]=value repeatedly.
   */
  void add(...) {
    vadd(_arguments,_argptr);
  }
  void vadd(TypeInfo[] arguments, void* argptr) {
    for (int k=0;k<arguments.length;k++) {
      TypeInfo tik = typeid(Key);
      if (arguments[k] == tik) {
        Key key = va_arg!(Key)(argptr);
        k++;
	addItem(key,va_arg!(Value)(argptr));
      } else {
	version(WithBox) {
	Box b = box(tik,argptr);
        Key key = unbox!(Key)(b);
        k++;
	TypeInfo tiv = arguments[k];
        b = box(tiv,argptr);
	addItem(key,unbox!(Value)(b));
	argptr += va_argumentLength(tiv.tsize());
	}
      }
    }
  }
  /** Construct a container with specified contents */
  static MultiAA make(...) {
    MultiAA res;
    res.vadd(_arguments,_argptr);
    return res;
  }
  }

  Key[] keys() { return impl.keys; }
  Value[][] values() { return impl.values; }
  int opApply(int delegate(inout Value x) dg){
    int res;
L0: foreach(inout Value[] item; impl) {
      foreach(inout Value val; item) {
	res = dg(val);
	if (res) break L0;
      }
    }
    return res;
  }
  int opApply(int delegate(inout Key key, inout Value x) dg){
    int res;
L1: foreach(Key key, inout Value[] item; impl) {
      foreach(inout Value val; item) {
	res = dg(key,val);
	if (res) break L1;
      }
    }
    return res;
  }
}

// Adapter for a sorted MultiAA
template SortedMultiAA(Key,Value) {
 alias MultiAA!(Key,Value,SortedAA!(Key,Value[])) SortedMultiAA;
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;
version (MinTLUnittest) {
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.multiaa unittest\n");

    // test MultiSet
    MultiAA!(int,char[]) ma2;
    ma2.add(22,"hello",-100,"there",22,"world");
    static char[][2] res = ["hello","world"];
    static char[][1] res2 = ["there"];
    char[][] vv = ma2[22];
    assert( ma2[22].length == 2);
    assert( ma2[22] == res);
    assert( ma2[-100] == res2);
    int count22;
    int count;
    foreach( int key, char[] item; ma2 ) {
      if (key == 22) {
	count22++;
      } else {
	count++;
      }
    }
    assert( count22 == 2 );
    assert( count == 1 );
    ma2.remove(-100);
    assert( ma2.length == 2 );
    ma2.remove(22,"hello");
    static char[][1] res3 = ["world"];
    assert( ma2[22] == res3);
    assert( ma2.length == 1 );
    ma2.remove(22);
    assert( ma2.length == 0 );
    assert( ma2.isEmpty );

    // test SortedMultiSet
    SortedMultiAA!(char[],int) s3;
    s3.add("hello",10,"world",20);
    s3.addItem("hello",40);
    int[] vals = s3["hello"];
    assert( s3["hello"].length == 2);
    assert( vals[0] == 10 && vals[1] == 40 );
    vals = s3["world"];
    assert(  vals.length == 1 && vals[0] == 20 );

    version (MinTLVerboseUnittest) 
      printf("finished mintl.multiaa unittest\n");
  }
}
+/