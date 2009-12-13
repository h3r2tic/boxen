/** \file arrayheap.d
 * \brief A heap (complete binary tree) backed by an array
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.6
 */

module mintl.arrayheap;

private {
  import mintl.share; // for ~ and ~=
  import mintl.mem;
  //import std.string;
}

/** \class ArrayHeap
 * \brief A heap (complete binary tree) backed by an array
 *
 * An ArrayHeap!(Value) is a heap of data of type Value backed
 * by an array. Adding to the tail and removing the head of the heap
 * are O(log(n)) operations. The items in the heap are maintained
 * in sorted order with the largest item at index 0 and for the nth item
 * the items at index 2*n+1 and 2*n+2 are smaller (or equal to)
 * item n.
 *
 * The optional allocator parameter ArrayHeap!(Value,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct ArrayHeap(Value, Alloc = GCAllocator) {

  alias ArrayHeap   ContainerType;
  alias Value       ValueType;
  alias size_t      IndexType;

  Value[] data;   ///< backing array. null by default, grows as needed

  invariant {
    assert( tail <= data.length );
  }

  /** signature for a custom comparison function */
  alias int delegate(Value* a, Value* b) CompareFcn;

  /** Set custom comparison function.   */
  void compareFcn(CompareFcn cmp) {
    cmpFcn = cmp;
  }

  /** Get heap contents as dynamic array slice of backing array.   */
  Value[] values() {
    return data[0..tail];
  }

  /** Adds an item to the heap. Increases capacity if needed.   */
  void addTail(Value v) {
    capacity(tail+1);
    data[tail++] = v;
    fixupTail();
  }

  /** Removes and returns the head item of the heap. If the target
   * heap is empty an IndexOutOfBoundsException is thrown unless
   * version=MinTLNoIndexChecking is set.
   */
  Value takeHead() {
    version (MinTLNoIndexChecking) {
      // no error checking
    } else {
      if (tail == 0)
	throw new IndexOutOfBoundsException();
    }
    Value val = data[0];
    data[0] = data[--tail];
    data[tail] = Value.init;
    fixupHead();
    return val;
  }

  /** Removes the head item of the heap.   */
  void removeHead() {
    version (MinTLNoIndexChecking) {
      // no error checking
    } else {
      if (tail == 0)
	throw new IndexOutOfBoundsException();
    }
    data[0] = data[--tail];
    data[tail] = Value.init;
    fixupHead();
  }

  /** Get the length of heap.   */
  size_t length() {
     return tail;
  }

  /** Test if container is empty.   */
  bool isEmpty() { 
    return tail == 0;
  }

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      if (data.ptr)
	Alloc.gcFree(data.ptr);
    }
    *this = ArrayHeap.init;
  }

  /** Get the nth item in the heap from head.   */
  Value opIndex(size_t n) {
    return data[n];
  }

  /** Get a pointer to the nth item in the heap   */
  Value* lookup(size_t n) {
    return &data[n];
  }

  /** Set the nth item in the heap.   */
  void opIndexAssign(Value val, size_t n) {
    data[n] = val;
  }

  /** Duplicates a heap.   */
  ArrayHeap dup() {
    ArrayHeap res;
    static if (is(Alloc == GCAllocator)) {
      res.data = data.dup;
    } else {
      Value* p = cast(Value*)Alloc.malloc(data.length * Value.sizeof);
      res.data = p[0 .. data.length];
      res.data[] = data[];
    }
    res.tail = tail;
    res.cmpFcn = cmpFcn;
    return res;
  }

  /** Test for equality of two heaps.   */
  int opEquals(ArrayHeap c) {
    size_t len = length;
    if (len !is c.length)
      return 0;
    size_t a,b;
    a = 0;
    b = 0;
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < len; k++) {
      if (!ti.equals(&data[a],&c.data[b]))
	return 0;
      a++;
      b++;
    }
    return 1;
  }

  /** Compare two heaps.   */
  int opCmp(ArrayHeap c) {
    size_t len = length;
    if (len > c.length)
      len = c.length;
    size_t a,b;
    a = 0;
    b = 0;
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < len; k++) {
      int cmp = ti.compare(&data[a],&c.data[b]);
      if (cmp)
	return cmp;
      a++;
      b++;
    }
    return cast(int)length - cast(int)c.length;
  }

  /** Returns a short string representation of the heap. */
  /+char[] toString() {
    return "[ArrayHeap length " ~ std.string.toString(tail) ~ "]";
  }+/

  /** Iterates over the heap from head to tail calling delegate to
   * perform an action. The value is passed to the delegate.
   */
  int opApplyNoKey(int delegate(inout Value x) dg){
    int res = 0;
    for (size_t k=0; k < tail; k++) {
      res = dg(data[k]);
      if (res) break;
    }
    return res;
  }

  /** Iterates over the heap from head to tail calling delegate to
   * perform an action. The index from 0 and the value are passed
   * to the delegate.
   */
  int opApplyWithKey(int delegate(inout size_t n, inout Value x) dg){
    int res = 0;
    for (size_t k=0; k < tail; k++) {
      res = dg(k,data[k]);
      if (res) break;
    }
    return res;
  }

  alias opApplyNoKey opApply;
  alias opApplyWithKey opApply;

  /** Ensure the minimum capacity of heap.   */
  void capacity(size_t cap) {
    if (cap > data.length) {
      cap = (cap+1)*2;
      static if (is(Alloc == GCAllocator)) {
	data.length = cap;
      } else {
	Value* p = data.ptr;
	p = cast(Value*)Alloc.gcRealloc(p,cap*Value.sizeof);
	p[data.length .. cap] = Value.init;
	data = p[0 .. cap];
      }
    }
  }

  // Helper functions

  // enforce heap invariant after a new head
  private void fixupHead() {
    size_t n = 0;
    TypeInfo ti = typeid(Value);
    if (cmpFcn is null) {
      cmpFcn = cast(CompareFcn)&ti.compare;
    }
    for (;;) {
      size_t n1 = 2*n+1;
      if (n1 >= tail) break;
      if ((n1 != tail-1) && (cmpFcn(&data[n1],&data[n1+1]) < 0))
	n1++;
      if (cmpFcn(&data[n],&data[n1]) < 0) {
	ti.swap(&data[n],&data[n1]);
	n = n1;
      } else {
	break;
      }
    }
  }

  // enforce heap invariant after a new tail
  private void fixupTail() {
    size_t n = tail-1;
    TypeInfo ti = typeid(Value);
    if (cmpFcn is null) {
      cmpFcn = cast(CompareFcn)&ti.compare;
    }
    size_t n1 = (n-1)>>1;
    while ((n > 0) && (cmpFcn(&data[n],&data[n1]) > 0)) {
      ti.swap(&data[n],&data[n1]);
      n = n1;
      n1 = (n-1)>>1;
    }
  }
  
  // added by h3
  void eraseNoDelete() {
  	tail = 0;
  }

  private CompareFcn cmpFcn;
  private size_t tail;
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;
version (MinTLUnittest) {
  private import std.string;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("started mintl.arrayheap unittest\n");

    ArrayHeap!(int) x,y,z;
    x.data = new int[10];
    x.addTail(5);
    x.addTail(3);
    x.addTail(4);
    assert( x.length == 3 );
    assert( x[0] == 5 );
    assert( x[x.length-1] == 4 );

    y = x.dup;

    assert( x == y );

    assert( x.takeHead == 5 );
    assert( x.takeHead == 4 );
    assert( x.takeHead == 3 );
    assert( x.length == 0 );

    y.addTail(6);
    int[10] y2;
    int k=0;
    foreach(int val; y) {
      y2[k++] = val;
    }
    assert( y2[0] == 6 );
    assert( y2[1] == 5 );
    assert( y2[2] == 4 );
    assert( y2[3] == 3 );

    k=0;
    foreach(size_t n, int val; y) {
      y2[n] = val;
    }
    assert( y2[0] == 6 );
    assert( y2[1] == 5 );
    assert( y2[2] == 4 );
    assert( y2[3] == 3 );

    ArrayHeap!(int,MallocNoRoots) xm;
    for (int k=0;k<100;k++)
      xm.addTail(k);
    for (int k=0;k<100;k++)
      assert( xm.takeHead == 99-k );
    xm.clear();

    version (MinTLVerboseUnittest) 
      printf("finished mintl.arrayheap unittest\n");
  }
}
