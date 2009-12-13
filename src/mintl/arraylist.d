/** \file arraylist.d
 * \brief A list backed by an array. This container can
 * also be used as an array with managed capacity by only
 * inserting and removing from the tail and keeping the head fixed
 * at 0.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.7.1
 */

module mintl.arraylist;

private import mintl.share; // for ~ and ~=
private import mintl.sorting;
import mintl.mem;

private extern(C) void *memmove(void *, void *, uint);

//debug = dArrayList; // can also pass at command line

/** \class ArrayList
 * \brief A bounded list backed by an array
 *
 * An ArrayList!(Value) is a list of data of type Value backed
 * by a circular array. The performance of ArrayLists is on the same
 * order as for arrays except adding an element to the head of an
 * ArrayList is constant. The backing array can be dynamic or static
 * arrays and should be set prior to use by assigning to the
 * <tt>data</tt> property or the <tt>capacity</tt> property. The
 * ArrayList will automatically grow the backing array if needed.
 *
 * An ArrayList can also be used as an array with managed capacity.
 * To do so only insert and remove from the tail and keep the head fixed
 * at 0.
 *
 * The optional ReadOnly parameter ArrayList!(Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter ArrayList!(Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct ArrayList(Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias ArrayList   ContainerType;
  alias ArrayList   SliceType;
  alias Value       ValueType;
  alias size_t      IndexType;
  alias ReadOnly    isReadOnly;

  Value[] data;   ///< backing array. null by default.

  invariant {
    assert( data.length == 0 || start < data.length );
    assert( len <= data.length );
  }

  /** Get a ReadOnly view of the container */
  .ArrayList!(Value, true, Alloc) readonly() {
    .ArrayList!(Value, true, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .ArrayList!(Value, false, Alloc) readwrite() {
    .ArrayList!(Value, false, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  static if (!ReadOnly) {

  /** Appends an item to the tail of the list.  If the target list is
   *  a sub-list call addAfter instead of addTail to insert an item
   *  after a sub-list. Increases capacity if needed.
   */
  void addTail(Value v) {
    capacity(length+1);
    data[addi(start,len)] = v;
    len++;
  }

  /** Appends a list to the tail of the target list.  If the target
   * list is a sub-list call addAfter instead of addTail to insert
   * another list after a sub-list. Increases capacity if needed.
   */
  void addTail(ArrayList v) {
    size_t vlen = v.length;
    capacity(len+vlen);
    copyBlock(v,data,addi(start,len),vlen);
    len += vlen;
  }

  /** overload ~ and ~=  */
  mixin MListCatOperators!(ArrayList);

  /** Removes and returns the tail item of the list.  If the target
   * list is empty an IndexOutOfBoundsException is thrown unless
   * version=MinTLNoIndexChecking is set.
   */
  Value takeTail() {
    boundsCheck(length-1);
    len--;
    size_t n = addi(start,len);
    Value val = data[n];
    data[n] = Value.init;
    return val;
  }

  /** Removes the tail item of the list.   */
  void removeTail() {
    boundsCheck(length-1);
    len--;
    data[addi(start,len)] = Value.init;
  }

  /** Prepends an item to the head of the target list.  If the target
   *  list is a sub-list call addBefore instead of addHead to insert an
   *  after a sub-list. Increases capacity if needed.
   */
  void addHead(Value v) {
    debug(dArrayList) printf(" add %d %u\n",start-1,dec(start));
    capacity(len+1);
    start = dec(start);
    data[start] = v;
    len++;
  }

  /** Prepends a list to the head of the target list.  If the target
   *  list is a sub-list call addBefore instead of addHead to insert a
   *  list before a sub-list. Increases capacity if needed.
   */
  void addHead(ArrayList v) {
    size_t vlen = v.length;
    capacity(len+vlen);
    size_t newhead = subi(start,vlen);
    copyBlock(v,data,newhead,vlen);
    start = newhead;
    len += vlen;
  }

  /** Removes and returns the head item of the list. If the target
   * list is empty an IndexOutOfBoundsException is thrown unless
   * version=MinTLNoIndexChecking is set.
   */
  Value takeHead() {
    boundsCheck(length-1);
    Value val = data[start];
    data[start] = Value.init;
    start = inc(start);
    debug(dArrayList) printf("%d %d\n",start,val);
    len--;
    return val;
  }

  /** Removes the head item of the list.   */
  void removeHead() {
    boundsCheck(len-1);
    data[start] = Value.init;
    start = inc(start);
    len--;
    debug(dArrayList) printf("%d\n",start);
  }

  /** Insert a list before a sub-list. Increases capacity if needed.   */
  void addBefore(ArrayList subv, ArrayList v) {
    size_t vlen = v.length;
    if (vlen == 0) return;
    capacity(length+vlen);
    size_t tlen = subv.start >= start ? subv.start-start : data.length-start+subv.start;
    size_t newhead = subi(start,vlen);
    moveBlockLeft(start,tlen,newhead);
    copyBlock(v,data,subi(subv.start,vlen),vlen);
    start = newhead;
    len += vlen;
  }

  /** Insert a list after a sub-list. Increases capacity if needed.  */
  void addAfter(ArrayList subv, ArrayList v) {
    size_t vlen = v.length;
    if (vlen == 0) return;
    capacity(length+vlen);
    size_t tail = addi(start,len);
    size_t stail = addi(subv.start,subv.len);
    size_t tlen = stail <= tail ? tail-stail : data.length-stail+tail;
    moveBlockRight(stail,tlen,addi(stail,vlen));
    copyBlock(v,data,stail,vlen);
    len += vlen;
  }

  /** Set the length of list.   */
  void length(size_t len) {
    capacity(len);
    this.len = len;
  }

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      if (data.ptr)
	Alloc.gcFree(data.ptr);
    }
    *this = ArrayList.init;
  }

  /** Set the nth item in the list from head.  Indexing out of bounds
   * throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  void opIndexAssign(Value val, size_t n) {
    boundsCheck(n);
    data[addi(start,n)] = val;
  }

  /** Set the value of one-item slice (more generally the head value). */
  void value(Value newValue) {
    opIndexAssign(newValue,0);
  }

  /** Removes a sub-list from the list.   */
  void remove(ArrayList sublist) {
    size_t tail = addi(start,len);
    size_t slen = sublist.len;
    size_t stail = addi(sublist.start,slen);
    size_t tlen = stail <= tail ? tail-stail : data.length-stail+tail;
    debug(dArrayList) printf("remove %d %d\n",sublist.start, sublist.length);
    moveBlockLeft(stail, tlen, sublist.start);
    fillBlock(subi(tail,slen),slen,Value.init);
    len -= slen;
    debug(dArrayList) printf("removed %d %d\n",start, len);
  }

  /** Removes an item from the list, if present.   */
  void remove(size_t index) {
    ArrayList item = opSlice(index, index+1);
    remove(item);
  }

  /** Removes an item from the list and returns the value, if present.   */
  Value take(size_t index) {
    ArrayList item = opSlice(index, index+1);
    Value val = item[0];
    remove(item);
    return val;
  }

  } // !ReadOnly

  /** Move a sub-list towards the tail by n items. If n is 
   * negative the sub-list moves towards the head. A positive end is
   * the tail, negative the head and 0 is both. By default moves to
   * to the next item. 
   */
  void next(int n = 1, int end = 0) {
    if (end)
      len += n<0?-n:n;
    if (end <= 0) {
      if (n<0) {
	start = subi(start,-n);
      } else {
	start = addi(start,n);
      }
    }
  }

  /** Get the length of list.   */
  size_t length() {
    return len;
  }

  private const double GrowthRate = 1.5;

  /** Ensure the minimum capacity of list.   */
  void capacity(size_t cap) {
    if (data.length < cap) {
      cap = cast(size_t)(cap*GrowthRate)+1;
      if (start > data.length - len) {
	size_t oldlen = data.length;
	size_t oldheadlen = oldlen - start;
	resizeData(cap);
	moveBlockRight(start,oldheadlen, cap - oldheadlen);
	start = cap-oldheadlen;
      } else {
	resizeData(cap);
      }
    }
  }

  // helper for capacity
  private void resizeData(size_t cap) {
    static if (is(Alloc == GCAllocator)) {
      data.length = cap;
    } else {
      Value* p = data.ptr;
      p = cast(Value*)Alloc.gcRealloc(p,cap*Value.sizeof);
      p[data.length .. cap] = Value.init;
      data = p[0 .. cap];
    }
  }

  /** Get the capacity of list.   */
  size_t capacity() {
    return data.length;
  }

  /** Test if container is empty.   */
  bool isEmpty() { 
    return len == 0;
  }

  /** Get the nth item in the list from head.  Indexing out of bounds
   * throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  Value opIndex(size_t n) {
    boundsCheck(n);
    return data[addi(start,n)];
  }

  /** Get the value of one-item slice (more generally the head value). 
   * Useful for expressions like x.tail.value or x.head.value. */
  Value value() {
    return opIndex(0);
  }

  // helper function to check if the index is legal
  private void boundsCheck(size_t n) {
    version (MinTLNoIndexChecking) {
    } else {
      if (n >= len) {
	throw new IndexOutOfBoundsException();
      }
    }
  }

  /** Create a one-item slice of the head.  */
  ArrayList head() {
    return opSlice(0,1);
  }

  /** Create a one-item slice of the tail.  */
  ArrayList tail() {
    size_t len = length;
    return opSlice(len-1,len);
  }

  /** Reverse a list in-place.   */
  ArrayList reverse() {
    size_t tlen = len / 2;
    size_t a,b;
    a = start;
    b = dec(addi(start,len));
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < tlen; k++) {
      debug(dArrayList) printf("swapping %d %d\n",data[a],data[b]);
      ti.swap(&data[a],&data[b]);
      a = inc(a);
      b = dec(b);
    }
    return *this;
  }

  /** Get list contents as dynamic array (a slice if possible).   */
  Value[] values() {
    Value[] buffer;
    if (start <= data.length-len) {
      buffer = data[start .. start+len];
    } else {
      buffer.length = len;
      buffer[0 .. data.length-start] = data[start .. data.length];
      buffer[data.length-start .. buffer.length] = 
	data[0 .. len - data.length - start];
    }
    return buffer;
  }

  /** Duplicates a list.   */
  ArrayList dup() {
    ArrayList res;
    static if (is(Alloc == GCAllocator)) {
      res.data = data.dup;
    } else {
      Value* p = cast(Value*)Alloc.malloc(data.length * Value.sizeof);
      res.data = p[0 .. data.length];
      res.data[] = data[];
    }
    res.start = start;
    res.len = len;
    return res;
  }

  /** Test for equality of two lists.   */
  int opEquals(ArrayList c) {
    if (len !is c.len)
      return 0;
    size_t a,b;
    a = start;
    b = c.start;
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < len; k++) {
      if (!ti.equals(&data[a],&c.data[b]))
	return 0;
      a = inc(a);
      b = inc(b);
    }
    return 1;
  }

  /** Compare two lists.   */
  int opCmp(ArrayList c) {
    size_t tlen = len;
    if (tlen > c.len)
      tlen = c.len;
    size_t a,b;
    a = start;
    b = c.start;
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < tlen; k++) {
      int cmp = ti.compare(&data[a],&c.data[b]);
      if (cmp)
	return cmp;
      a = inc(a);
      b = inc(b);
    }
    return cast(int)len - cast(int)c.len;
  }

  /** Create a sub-list from index a to b (exclusive).   */
  ArrayList opSlice(size_t a, size_t b) {
    ArrayList res;
    res.data = data;
    res.start = addi(start,a);
    res.len = b-a;
    debug(dArrayList) printf("slice %d %d\n",res.start,res.len);
    return res;
  }

  /** Create a sub-list from the head of a to the tail of b (inclusive).  */
  ArrayList opSlice(ArrayList a, ArrayList b) {
    ArrayList res;
    res.data = data;
    res.start = a.start;
    if (b.start >= a.start)
      res.len = b.start - a.start + b.len;
    else
      res.len = data.length - a.start + b.len + b.start;
    return res;
  }

  /** Iterates over the list from head to tail calling delegate to
   * perform an action. The value is passed to the delegate.
   */
  int opApplyNoKeyStep(int delegate(inout Value x) dg, int step = 1){
    int dg2(inout size_t n, inout Value x) {
      return dg(x);
    }
    return opApplyWithKeyStep(&dg2,step);
  }

  /** Iterates over the list from head to tail calling delegate to
   * perform an action. The index from 0 and the value are passed
   * to the delegate.
   */
  int opApplyWithKeyStep(int delegate(inout size_t n, inout Value x) dg, int step = 1){
    if (len == 0) return 0;
    int res = 0;
    size_t tail = addi(start,len);
    size_t istart = step>0 ? start : dec(tail);
    size_t iend = step>0 ? tail : dec(start);
    size_t n = step>0 ? 0 : len-1;
    for (size_t k = istart; k != iend;) {
      res = dg(n,data[k]);
      if (res) break;
      if (step < 0)
	k = subi(k,-step);
      else
	k = addi(k,step);
      n += step;
    }
    return res;
  }

  /** Iterates over the list from head to tail calling delegate to
   * perform an action. A one-item sub-list is passed to the delegate.
   */
  int opApplyIterStep(int delegate(inout ArrayList n) dg, int step = 1){
    ArrayList itr;
    itr.data = data;
    itr.len = 1;
    int dg2(inout size_t n, inout Value x) {
      itr.start = addi(start,n);
      return dg(itr);
    }
    return opApplyWithKeyStep(&dg2,step);
  }

  /** Iterate backwards over the list (from tail to head).
   *  This should only be called as the
   *  iteration parameter in a <tt>foreach</tt> statement
   */
  ArrayListReverseIter!(Value,ReadOnly,Alloc) backwards() {
    ArrayListReverseIter!(Value,ReadOnly,Alloc) res;
    res.list = this;
    return res;
  }

  /**  Helper functions for opApply   */
  mixin MOpApplyImpl!(ArrayList);
  alias opApplyNoKey opApply;
  alias opApplyWithKey opApply;
  alias opApplyIter opApply;
  
  ArrayList getThis(){return *this;}
  mixin MListAlgo!(ArrayList, getThis);
  mixin MRandomAccessSort!(ArrayList, getThis);

  /** Get a pointer to the nth item in the list from head.  Indexing
   * out of bounds throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  Value* lookup(size_t n) {
    boundsCheck(n);
    return &data[addi(start,n)];
  }

  // Helper functions

  // helper function to copy sections of the backing buffer
  private void moveBlockLeft(size_t srchead, size_t len, size_t desthead) {
    size_t ns = srchead;
    size_t nd = desthead;
    while (len > 0) {
      debug(dArrayList) printf("move left len %u\n",len);
      size_t sz = len;
      if (ns > data.length-sz) 
	sz = data.length-ns;
      if (nd > data.length-sz) 
	sz = data.length-nd;
      assert(sz != 0);
      memmove(&data[nd],&data[ns],sz*Value.sizeof);
      ns = addi(ns,sz);
      nd = addi(nd,sz);
      len -= sz;
    }
  }

  // helper function to copy sections of the backing buffer
  private void moveBlockRight(size_t srchead, size_t len, size_t desthead) {
    debug(dArrayList) printf("len %u\n",len);
    size_t ns = addi(srchead,len-1)+1;
    size_t nd = addi(desthead,len-1)+1;
    while (len > 0) {
      int sz = len;
      if (ns < sz)
	sz = ns;
      if (nd < sz)
	sz = nd;
      assert(sz != 0);
      memmove(&data[nd-sz],&data[ns-sz],sz*Value.sizeof);
      ns = dec(subi(ns,sz))+1;
      nd = dec(subi(nd,sz))+1;
      len -= sz;
    }
  }

  // helper function to copy sections of the backing buffer
  private void copyBlock(ArrayList src,
			 Value[] destdata,int desthead,
			 int len) {
    Value[] srcdata = src.data;
    int srchead = src.start;
    int ns = srchead;
    int nd = desthead;
    while (len > 0) {
      debug(dArrayList) printf("copy len %u %d %d len %d len %d\n",
			       len,ns,nd,srcdata.length,destdata.length);
      int sz = len;
      if (ns > srcdata.length-sz) 
	sz = srcdata.length-ns;
      if (nd > destdata.length-sz) 
	sz = destdata.length-nd;
      assert(sz != 0);
      memmove(&destdata[nd],&srcdata[ns],sz*Value.sizeof);
      ns = src.addi(ns,sz);
      nd = addi(nd,sz);
      len -= sz;
    }
  }

  // helper function to fill a section of the backing array
  private void fillBlock(size_t srchead, size_t len, Value val) {
    size_t ns = srchead;
    while (len > 0) {
      size_t sz = len;
      if (ns > data.length-sz) 
	sz = data.length-ns;
      assert(sz != 0);
      data[ns .. ns+sz] = val;
      ns = addi(ns,sz);
      len -= sz;
    }
  }

  // move index n by 1 with wrapping
  private size_t inc(size_t n) {
    return (n == data.length-1) ? 0 : n+1;
  }

  // move index n by -1 with wrapping
  private size_t dec(size_t n) {
    return (n == 0) ? data.length-1 : n-1;
  }

  // move index n by -diff with wrapping
  private size_t subi(size_t n, size_t diff) {
    size_t res;
    if (n < diff)
      res = data.length - diff + n;
    else
      res = n - diff;
    debug(dArrayList) printf("subi %d %d len %d got %d\n",n,diff,data.length,res);
    return res;
  }

  // move index n by diff with wrapping
  private size_t addi(size_t n, size_t diff) {
    size_t res;
    if (data.length - n <= diff)
      res = diff - (data.length - n);
    else
      res = n + diff;
    debug(dArrayList) printf("addi %d %d len %d got %d\n",n,diff,data.length,res);
    return res;
  }

  private size_t start, len;
}

// helper structure for backwards()
struct ArrayListReverseIter(Value,bit ReadOnly, Alloc=GCAllocator) {
  mixin MReverseImpl!(ArrayList!(Value,ReadOnly,Alloc));
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;
version (MinTLUnittest) {
  private import std.string;
  private import std.random;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("started mintl.arraylist unittest\n");

    ArrayList!(int) x,y,z;
    x.data = new int[10];
    x.add(5,3,4);
    assert( x[0] == 5 );
    assert( x[1] == 3 );
    assert( x[2] == 4 );
    assert( x.length == 3 );
    x.takeTail();
    x ~= 4;
    assert( x[2] == 4 );

    y = x.dup;

    assert( x == y );

    x.addHead(-1);
    x.addHead(-2);
    // private bug
    //    assert( x.start == x.data.length - 2 );
    assert( x.head == x[0 .. 1] );
    assert( x.length == 5 );
    assert( x.tail == x[4 .. 5] );
    assert( x.data[x.data.length-1] == -1);
    assert( x.data[x.data.length-2] == -2);
    assert( x.takeHead == -2 );
    assert( x.takeHead == -1 );
    assert( x[0] == 5 );
    assert( x[x.length-1] == 4 );
    assert( x.takeHead == 5 );
    assert( x.takeHead == 3 );
    assert( x.takeHead == 4 );
    assert( x.length == 0 );

    assert( y.length == 3 );
    assert( y[0] == 5 );
    assert( y[2] == 4 );
    y ~= 6;
    debug(dArrayList) printf("%d %d %d %d\n",y.start,y.tail_,y[0],y[3]);
    y = y.reverse;
    debug(dArrayList) printf("%d %d %d %d\n",y.start,y.tail_,y[0],y[3]);
    assert( y[0] == 6 );
    assert( y[1] == 4 );
    assert( y[2] == 3 );
    assert( y[3] == 5 );

    int[10] y2;
    int k=0;
    foreach(int val; y) {
      y2[k++] = val;
    }
    assert( y2[0] == 6 );
    assert( y2[1] == 4 );
    assert( y2[2] == 3 );
    assert( y2[3] == 5 );

    k=0;
    foreach(int val; y.backwards()) {
      y2[k++] = val;
    }
    assert( y2[0] == 5 );
    assert( y2[1] == 3 );
    assert( y2[2] == 4 );
    assert( y2[3] == 6 );

    k=0;
    foreach(size_t n, int val; y) {
      y2[n] = val;
    }
    assert( y2[0] == 6 );
    assert( y2[1] == 4 );
    assert( y2[2] == 3 );
    assert( y2[3] == 5 );

    k=0;
    foreach(ArrayList!(int) itr; y) {
      y2[k++] = itr[0];
    }
    assert( y2[0] == 6 );
    assert( y2[1] == 4 );
    assert( y2[2] == 3 );
    assert( y2[3] == 5 );
  
    ArrayList!(int) y3 = y[2..4];
    assert( y3.length == 2 );
    assert( y3[0] == 3 );
    assert( y3[1] == 5 );
    y3[0..1].swap(y3[1..2]);
    assert( y3[0] == 5 );
    assert( y3[1] == 3 );

    y3[0] = 10;
    assert( y[2] == 10 );

    y3.next(-1);
    assert( y3.length == 2 );
    assert( y3[0] == 4 );
    assert( y3[1] == 10 );
    y3.next(-1,-1);
    assert( y3.length == 3 );
    assert( y3[0] == 6 );
    assert( y3[2] == 10 );
    y3.next(1,1);
    assert( y3.length == 4 );
    assert( y3[0] == 6 );
    assert( y3[3] == 3 );

    ArrayList!(char[]) c = ArrayList!(char[]).make("a","a","a","a");
    assert( c.opIn("a") == c.head );
    assert( c.count("a") == 4 );
    for (int kk=0;kk<100;kk++) {
      c ~= toString(kk);
      c.takeHead();
    }

    // test addAfter, addBefore and remove
    ArrayList!(double) w;
    w.data = new double[30];
    for (int j=0;j<20;j++)
      w ~= j;
    w.remove(w[10..15]);
    assert( w.length == 15 );
    assert( w[10] == 15 );
    for (int j=0;j<5;j++)
      w.addHead(j);
    w.remove(w[2..7]);
    assert( w.length == 15 );
    ArrayList!(double) w2;
    w2.data = new double[30];
    for (k=0;k<20;k++)
      w2 ~= k;
    w.addBefore(w[5..7],w2[10..15]);
    assert( w.length == 20 );
    assert( w[0] == 4 );
    foreach( double d; w) {
      version (MinTLVerboseUnittest) 
	printf(" %g",d);
    }
    version (MinTLVerboseUnittest) 
      printf("\n");
    assert( w[5] == 10 );

    ArrayList!(int) cda = ArrayList!(int).make(20,30);
    cda.capacity = 20;
    assert( cda.capacity >= 20 );
    assert( cda.length == 2 );
    assert( cda.values == cda.data[0..2] );
    cda.length = 4;
    assert( cda.length == 4 );
    assert( cda[cda.length - 1] == 0 );
    cda.capacity = 40;
    assert( cda.length == 4 );
    assert( cda.data.length >= 40 );
    cda.addHead(40);
    cda.addHead(50); 
    cda.capacity = 50;
    uint ss = cda.capacity;
    assert( cda.length >= 6 );
    assert( cda[0] == 50 );
    assert( cda[1] == 40 );
    assert( cda[2] == 20 );
    assert( cda[3] == 30 );
    assert( cda[4] == 0 );

    ArrayList!(int,false,Malloc) xm = 
      ArrayList!(int,false,Malloc).make(10,20,30);
    assert( xm.takeTail == 30 );
    assert( xm.takeHead == 10 );
    for (int u;u<10000;u++) {
      xm ~= u;
    }
    xm.clear();
    assert( xm.isEmpty );

    // test simple sorting
    ArrayList!(int) s1;
    s1.add(40,300,-20,100,400,200);
    s1.sort();
    ArrayList!(int) s2 = ArrayList!(int).make(-20,40,100,200,300,400);
    assert( s1 == s2 );

    // test a large sort with default order
    ArrayList!(double) s3;
    for (k=0;k<1000;k++) {
      s3 ~= 1.0*rand()/100000.0 - 500000.0;
    }
    ArrayList!(double) s4 = s3.dup;
    s3.sort();
    for (k=0;k<999;k++) {
      assert( s3[k] <= s3[k+1] );
    }
    // test a large sort with custom order
    int cmp(double*x,double*y){return *x>*y?-1:*x==*y?0:1;}
    s4.sort(&cmp);
    for (k=0;k<999;k++) {
      assert( s4[k] >= s4[k+1] );
    }

    version (MinTLVerboseUnittest) 
      printf("finished mintl.arraylist unittest\n");
  }
}
