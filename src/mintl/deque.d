/** \file deque.d
 * \brief A resizable double-ended queue stored in blocks with 
 * constant time insertion at the front and tail.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.7.1
 */

module mintl.deque;

import mintl.mem;
private import mintl.share; // for ~ and ~=
private import mintl.sorting;

private extern(C) void *memmove(void *, void *, size_t);

//debug = dDeque; // can also pass at command line

/** \class Deque
 * \brief A resizable double-ended queue stored in blocks with
 * constant time insertion at the front and tail.
 *
 * A Deque!(Value) is a list of data of type Value backed by a
 * block-allocated array. The size of the allocation blocks varies
 * with the number of elements in the deque. The performance of Deques
 * is on the same order as for arrays except adding an element to the
 * head of a Deque is constant.
 *
 * The optional ReadOnly parameter Deque!(Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter Deque!(Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct Deque(Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias Deque   ContainerType;
  alias Deque   SliceType;
  alias Value   ValueType;
  alias size_t  IndexType;
  alias ReadOnly isReadOnly;

  alias Value* Block;
  const size_t psize = (void*).sizeof;

  invariant {
    assert( total() == 0 || start < total() );
    assert( len <= total() );
  }

  /** Get a ReadOnly view of the container */
  .Deque!(Value, true, Alloc) readonly() {
    .Deque!(Value, true, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .Deque!(Value, false, Alloc) readwrite() {
    .Deque!(Value, false, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  static if (ReadOnly) {
  /** Duplicates a deque.   */
    /* private bug
  Deque dup() {
    .Deque!(Value,false,Alloc) res;
    size_t cap = block(len)+1;
    if (len == 0) return res.readonly;
    static if (is(Alloc == GCAllocator)) {
      res.data = new Block[cap];
    } else {
      Block* p = cast(Block*)Alloc.malloc(cap * psize);
      res.data = p[0..cap];
      res.data[] = null;
    }
    res.addTail(this.readwrite);
    return res.readonly;
  }
    */
  } else {

  /** Appends an item to the tail of the deque.  If the target deque is
   *  a slice call addAfter instead of addTail to insert an item
   *  after a slice.
   */
  void addTail(Value v) {
    capacity(len+1);
    *plookup(addi(start,len)) = v;
    len++;
  }

  /** Appends a deque to the tail of the target deque.  If the target
   * deque is a slice call addAfter instead of addTail to insert
   * another deque after a slice.
   */
  void addTail(Deque v) {
    size_t vlen = v.len;
    if (vlen == 0) return;
    capacity(len+vlen);
    copyBlock(v, data, addi(start,len), vlen);
    len += vlen;
  }

  /** overload ~ and ~=  */
  mixin MListCatOperators!(Deque);

  /** Removes and returns the tail item of the deque.  If the target
   * deque is empty an IndexOutOfBoundsException is thrown unless
   * version=MinTLNoIndexChecking is set.
   */
  Value takeTail() {
    boundsCheck(len-1);
    len--;
    Value* pval = plookup(addi(start,len));
    Value val = *pval;
    *pval = Value.init;
    return val;
  }

  /** Removes the tail item of the deque.   */
  void removeTail() {
    boundsCheck(len-1);
    len--;
    *plookup(addi(start,len)) = Value.init;
  }

  /** Prepends an item to the head of the target deque.  If the target
   * deque is a slice call addBefore instead of addHead to insert an
   * item before a slice.
   */
  void addHead(Value v) {
    capacity(len+1);
    start = dec(start);
    *plookup(start) = v;
    len++;
  }

  /** Prepends a deque to the head of the target deque.  If the target
   *  deque is a slice call addBefore instead of addHead to insert a
   *  deque before a slice.
   */
  void addHead(Deque v) {
    size_t vlen = v.len;
    if (vlen == 0) return;
    capacity(len+vlen);
    size_t newhead = subi(start,vlen);
    copyBlock(v, data, newhead, vlen);
    start = newhead;
    len += vlen;
  }

  /** Removes and returns the head item of the deque. If the target
   * deque is empty an IndexOutOfBoundsException is thrown unless
   * version=MinTLNoIndexChecking is set.
   */
  Value takeHead() {
    boundsCheck(len-1);
    Value* pval = plookup(start);
    start = inc(start);
    Value val = *pval;
    *pval = Value.init;
    len--;
    debug(dDeque) printf("%d %d\n",start,val);
    return val;
  }

  /** Removes the head item of the deque.   */
  void removeHead() {
    boundsCheck(len-1);
    Value* pval = plookup(start);
    start = inc(start);
    len--;
    *pval = Value.init;
  }

  /** Insert a deque before a slice.   */
  void addBefore(Deque subv, Deque v) {
    size_t vlen = v.length;
    if (vlen == 0) return;
    capacity(len+vlen);
    size_t tlen = subv.start >= start ? subv.start-start : total-start+subv.start;
    size_t newhead = subi(start,vlen);
    debug(dDeque)printf("about to moveBlockLeft %d\n",tlen);
    moveBlockLeft(start,tlen,newhead);
    copyBlock(v,data,subi(subv.start,vlen),vlen);
    start = newhead;
    len += vlen;
  }

  /** Insert a deque after a slice.   */
  void addAfter(Deque subv, Deque v) {
    size_t vlen = v.length;
    if (vlen == 0) return;
    capacity(len+vlen);
    size_t tail = addi(start,len);
    size_t subtail = addi(subv.start,subv.len);
    size_t tlen = subtail <= tail ? tail-subtail : total-subtail+tail;
    moveBlockRight(subtail,tlen,addi(subtail,vlen));
    copyBlock(v,data,subtail,vlen);
    len += vlen;
  }

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      foreach (Block b; data) {
	Alloc.gcFree(b);
      }
      if (data.ptr)
	Alloc.free(data.ptr);
    }
    *this = Deque.init;
  }

  /** Set the nth item in the deque from head.  Indexing out of bounds
   * throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  void opIndexAssign(Value val, size_t n) {
    boundsCheck(n);
    *plookup(addi(start,n)) = val;
  }

  /** Set the value of one-item slice (more generally the head value). */
  void value(Value newValue) {
    opIndexAssign(newValue,0);
  }

  /** Removes a slice from the deque.   */
  void remove(Deque sublist) {
    size_t tail = addi(start,len);
    size_t slen = sublist.len;
    size_t stail = addi(sublist.start,slen);
    size_t tlen = stail <= tail ? tail-stail : data.length-stail+tail;
    debug(dArrayList) printf("remove %d %d\n",sublist.start, sublist.length);
    moveBlockLeft(stail, tlen, sublist.start);
    fillBlock(subi(tail,slen),slen,Value.init);
    len -= slen;
  }

  /** Removes an item from the list and returns the value, if present.   */
  Value take(size_t index) {
    Deque item = opSlice(index, index+1);
    Value val = item[0];
    remove(item);
    return val;
  }

  /** Removes an item from the deque if present.   */
  void remove(size_t index) {
    Deque item = opSlice(index, index+1);
    remove(item);
  }

  /** Reverse a deque in-place.   */
  Deque reverse() {
    size_t tlen = len / 2;
    size_t a,b;
    a = start;
    b = dec(addi(start,len));
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < tlen; k++) {
      ti.swap(plookup(a),plookup(b));
      a = inc(a);
      b = dec(b);
    }
    return *this;
  }

  /** Duplicates a deque.   */
  Deque dup() {
    Deque res;
    if (len == 0) return res;
    size_t cap = block(len)+1;
    static if (is(Alloc == GCAllocator)) {
      res.data = new Block[cap];
    } else {
      Block* p = cast(Block*)Alloc.malloc(cap * psize);
      res.data = p[0..cap];
      res.data[] = null;
    }
    res.addTail(*this);
    return res;
  }

  } // !ReadOnly

  /** Move a slice towards the tail by n items. If n is 
   * negative the slice moves towards the head. A positive end is
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

  /** Get the length of deque.   */
  size_t length() {
    return len;
  }

  /** Test if container is empty.   */
  bool isEmpty() { 
    return len == 0;
  }

  /** Get the nth item in the deque from head.  Indexing out of bounds
   * throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  Value opIndex(size_t n) {
    boundsCheck(n);
    return *plookup(addi(start,n));
  }

  // lookup an index and return a pointer to the slot
  private Value* plookup(size_t n) {
    debug(dDeque) printf("plookup for %d block %d offset %d blocklen %d\n",
			 n,block(n),offset(n),data.length);
    debug(dDeque) printf(" plookup got %p\n", data[block(n)]);
    size_t bn = block(n);
    //    if (bn >= data.length) bn -= data.length;
    Block b = data[bn];
    if (b is null)
      data[bn] = b = newBlock();;
    return b+offset(n);
  }

  // allocate a new block 
  private Block newBlock() {
    static if (is(Alloc == GCAllocator)) {
        return (new Value[BlockSize]).ptr; 
    } else {
      Value* p = cast(Value*)Alloc.gcMalloc(BlockSize * Value.sizeof);
      Value[] q = p[0..BlockSize];
      q[] = Value.init;
      return p;
    }
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

  /** Get deque contents as dynamic array.   */
  Value[] values() {
    Value[] res = new Value[len];
    foreach(size_t k, Value val; *this)
      res[k] = val;
    return res;
  }

  /** Test for equality of two deques.   */
  int opEquals(Deque c) {
    if (len !is c.len)
      return 0;
    size_t a,b;
    a = start;
    b = c.start;
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < len; k++) {
      Value* bn = c.data[block(b)]+offset(b);
      if (!ti.equals(plookup(a),bn))
	return 0;
      a = inc(a);
      b = inc(b);
    }
    return 1;
  }

  /** Compare two lists.   */
  int opCmp(Deque c) {
    size_t tlen = len;
    if (tlen > c.len)
      tlen = c.len;
    size_t a,b;
    a = start;
    b = c.start;
    TypeInfo ti = typeid(Value);
    for (size_t k = 0; k < tlen; k++) {
      Value* bn = c.data[block(b)]+offset(b);
      int cmp = ti.compare(plookup(a),bn);
      if (cmp)
	return cmp;
      a = inc(a);
      b = inc(b);
    }
    return cast(int)len - cast(int)c.len;
  }

  /** Create a slice from index a to b (exclusive).   */
  Deque opSlice(size_t a, size_t b) {
    Deque res;
    res.data = data;
    res.start = addi(start,a);
    res.len = b-a;
    return res;
  }

  /** Create a slice from the head of a to the tail of b (inclusive).  */
  Deque opSlice(Deque a, Deque b) {
    Deque res;
    res.data = data;
    res.start = a.start;
    if (b.start >= a.start)
      res.len = b.start - a.start + b.len;
    else
      res.len = data.length - a.start + b.len + b.start;
    return res;
  }

  /** Create a one-item slice of the head.   */
  Deque head() {
    return opSlice(0,1);
  }

  /** Create a one-item slice of the tail.   */
  Deque tail() {
    return opSlice(len-1,len);
  }

  /** Iterates over the deque from head to tail calling delegate to
   * perform an action. The value is passed to the delegate.
   */
  int opApplyNoKeyStep(int delegate(inout Value x) dg,int step=1){
    int dg2(inout size_t n, inout Value x) {
      return dg(x);
    }
    return opApplyWithKeyStep(&dg2,step);
  }

  /** Iterates over the deque from head to tail calling delegate to
   * perform an action. The index from 0 and the value are passed
   * to the delegate.
   */
  int opApplyWithKeyStep(int delegate(inout size_t n, inout Value x) dg,
			 int step = 1){
    if (len == 0) return 0;
    int res = 0;
    size_t tail = addi(start,len);
    size_t istart = step>0 ? start : dec(tail);
    size_t iend = step>0 ? tail : dec(start);
    size_t n = step>0 ? 0 : len-1;
    for (size_t k = istart; k != iend;) {
      res = dg(n,data[block(k)][offset(k)]);
      if (res) break;
      if (step < 0)
	k = subi(k,-step);
      else
	k = addi(k,step);
      n += step;
    }
    return res;
  }

  /** Iterates over the deque from head to tail calling delegate to
   * perform an action. A one-item slice is passed to the delegate.
   */
  int opApplyIterStep(int delegate(inout Deque n) dg, int step = 1){
    Deque itr;
    itr.data = data;
    itr.len = 1;
    int dg2(inout size_t n, inout Value x) {
      itr.start = addi(start,n);
      return dg(itr);
    }
    return opApplyWithKeyStep(&dg2,step);
  }

  /** Iterate backwards over the deque (from tail to head).
   *  This should only be called as the
   *  iteration parameter in a <tt>foreach</tt> statement
   */
  DequeReverseIter!(Value,ReadOnly,Alloc) backwards() {
    DequeReverseIter!(Value,ReadOnly,Alloc) res;
    res.list = this;
    return res;
  }

  /**  Helper functions for opApply   */
  mixin MOpApplyImpl!(Deque);
  alias opApplyNoKey opApply;
  alias opApplyWithKey opApply;
  alias opApplyIter opApply;

  Deque getThis(){return *this;}
  mixin MListAlgo!(Deque, getThis);
  mixin MRandomAccessSort!(Deque, getThis);

  /** Get a pointer to the nth item in the deque from head.  Indexing
   * out of bounds throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  Value* lookup(size_t n) {
    boundsCheck(n);
    return plookup(addi(start,n));
  }

  // Helper functions

  // compute the block number for an index
  private size_t block(size_t n) { 
    return n >> BlockShift; 
  }

  // compute the offset within a block for an index
  private size_t offset(size_t n) {
    return n & BlockMask; 
  }

  /** Ensure the minimum capacity of list.   */
  void capacity(size_t cap) {
    cap = block(cap)+1;
    if (data.length <= cap) {
      cap = cap*2;
      debug(dDeque) printf("growing capacity from %d to %d\n",data.length, cap);
      if (start + len > total) {
	size_t oldlen = data.length;
	size_t offs = cap-oldlen;
	size_t h = block(start);
	resizeData(cap);
	memmove(&data[h+offs],&data[h],(oldlen-h)*psize);
	if (h == block(start+len)%data.length) {
	  static if (is(Alloc == GCAllocator)) {
	    data[h+offs] = data[h+offs][0..BlockSize].dup.ptr;
	  } else {
	    Block p = newBlock();
	    p[0 .. BlockSize] = data[h+offs][0 .. BlockSize];
	    data[h+offs] = p;
	  }
	  data[h][offset(start) .. BlockSize] = Value.init;
	  data[h+offs][0 .. offset(start+len)] = Value.init;
	  data[h+1 .. h+offs] = null;
	} else {
	  data[h .. h+offs] = null;
	}
	start += offs*BlockSize;
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
      Block* p = data.ptr;
      p = cast(Block*)Alloc.realloc(p,cap*psize);
      p[data.length .. cap] = null;
      data = p[0 .. cap];
    }
  }

  /** Get the capacity of list.   */
  size_t capacity() {
    return total();
  }

  private const size_t BlockShift = Value.sizeof>128 ? 1 : 7;
  private const size_t BlockSize = 1 << BlockShift;
  private const size_t BlockMask = BlockSize - 1;

  // Helper functions

  // helper function to copy sections of the backing buffer
  private void moveBlockLeft(size_t srchead, size_t len, size_t desthead) {
    size_t ns = srchead;
    size_t nd = desthead;
    debug(dDeque)printf("moveBlockLeft %d\n",len);
    while (len > 0) {
      size_t sz = len;
      size_t offs = offset(ns);
      size_t offd = offset(nd);
      size_t bn = block(ns);
      Block srcblock = data[bn];
      if (srcblock == null)
	data[bn] = srcblock = newBlock();
      bn = block(nd);
      Block destblock = data[bn];
      if (destblock == null)
	data[bn] = destblock = newBlock();
      if (offs+sz > BlockSize) 
	sz = BlockSize-offs;
      if (offd+sz > BlockSize) 
	sz = BlockSize-offd;
      assert(sz != 0);
      memmove(&destblock[offd],&srcblock[offs],sz*Value.sizeof);
      ns = addi(ns,sz);
      nd = addi(nd,sz);
      len -= sz;
    }
  }

  // helper function to copy sections of the backing buffer
  private void moveBlockRight(size_t srchead, size_t len, size_t desthead) {
    size_t ns = addi(srchead,len-1)+1;
    size_t nd = addi(desthead,len-1)+1;
    while (len > 0) {
      size_t sz = len;
      size_t bn = block(ns);
      size_t offs = offset(ns);
      size_t offd = offset(nd);
      Block srcblock = data[bn];
      if (srcblock == null)
	data[bn] = srcblock = newBlock();
      bn = block(nd);
      Block destblock = data[bn];
      if (destblock == null)
	data[bn] = destblock = newBlock();
      if (offs < sz)
	sz = offs;
      if (offd < sz)
	sz = offd;
      assert(sz != 0);
      memmove(&destblock[offd],&srcblock[offs],sz*Value.sizeof);
      ns = dec(subi(ns,sz))+1;
      nd = dec(subi(nd,sz))+1;
      len -= sz;
      debug(dDeque)printf("moveBlockRight %d\n",sz);
    }
  }

  // helper function to copy sections of the backing buffer
  private void copyBlock(Deque src,
			 Block[] destdata,
			 uint desthead,
			 uint len) {
    Block[] srcdata = src.data;
    int srchead = src.start;
    int ns = srchead;
    int nd = desthead;
    while (len > 0) {
      int sz = len;
      size_t offs = offset(ns);
      size_t offd = offset(nd);
      size_t bn = block(ns);
      Block srcblock = srcdata[bn];
      if (srcblock == null)
	srcdata[bn] = srcblock = newBlock();
      if (offs+sz > BlockSize) 
	sz = BlockSize-offs;
      bn = block(nd);
      Block destblock = destdata[bn];
      if (destblock == null)
	destdata[bn] = destblock = newBlock();
      if (offd+sz > BlockSize) 
	sz = BlockSize-offd;
      assert(sz != 0);
      memmove(&destblock[offd],&srcblock[offs],sz*Value.sizeof);
      ns = src.addi(ns,sz);
      nd = addi(nd,sz);
      len -= sz;
      debug(dDeque)printf("copyBlock %d\n",sz);
    }
  }

  // helper function to fill a section of the backing array
  private void fillBlock(size_t srchead, size_t len, Value val) {
    size_t ns = srchead;
    while (len > 0) {
      size_t sz = len;
      size_t bn = block(ns);
      size_t off = offset(ns);
      Block block = data[bn];
      if (block == null)
	data[bn] = block = newBlock();
      if (off+sz > BlockSize) 
	sz = BlockSize-off;
      assert(sz != 0);
      block[off .. off+sz] = val;
      ns = addi(ns,sz);
      len -= sz;
      debug(dDeque)printf("fillBlock %d\n",sz);
    }
  }

  // move index n by 1 with wrapping
  private size_t inc(size_t n) {
    return (n == total()-1) ? 0 : n+1;
  }

  // move index n by -1 with wrapping
  private size_t dec(size_t n) {
    return (n == 0) ? total()-1 : n-1;
  }

  // move index n by -diff with wrapping
  private size_t subi(size_t n, size_t diff) {
    size_t res;
    if (n < diff)
      res = total() - diff + n;
    else
      res = n - diff;
    return res;
  }

  // move index n by diff with wrapping
  private size_t addi(size_t n, size_t diff) {
    size_t res;
    if (total() - n <= diff) {
      res = diff - (total() - n);
    } else
      res = n + diff;
    return res;
  }

  private size_t total(){ return data.length << BlockShift; }

  private Block[] data; // array of blocks of data
  private size_t start, len;
}

// helper structure for backwards()
struct DequeReverseIter(Value,bit ReadOnly,Alloc) {
  mixin MReverseImpl!(Deque!(Value,ReadOnly,Alloc));
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;
version (MinTLUnittest) {
  private import std.string;
  private import std.random;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("started mintl.deque unittest\n");

    Deque!(int) x,y,z;
    x.addTail(22);
    x.addTail(33);
    assert( x[0] == 22 );
    assert( x[1] == 33 );
    x.addHead(11);
    assert( x[0] == 11 );
    assert( x[2] == 33 );

    y = x.dup;

    assert( y.length == 3 );
    assert( y[0] == 11 );
    assert( y[2] == 33 );
    z = x.dup;
    z.addTail(y);
    assert( z.length == 6 );
    assert( z[0] == 11 );
    assert( z[2] == 33 );
    assert( z[3] == 11 );
    assert( z[4] == 22 );
    assert( z[5] == 33 );

    Deque!(int,false,Malloc) mx;
    mx.add(30,40,50);
    assert( mx.takeHead == 30 );
    assert( mx.takeTail == 50 );
    for(int u = 0;u<10000;u++) {
      mx~=u;
    }
    mx.clear();
    assert( mx.isEmpty );

    x = x.init;
    x ~= 5;
    x ~= 3;
    x ~= 4;
    assert( x[0] == 5 );
    assert( x[1] == 3 );
    assert( x[2] == 4 );
    assert( x.length == 3 );

    x.reverse();
    assert( x[2] == 5 );
    assert( x[1] == 3 );
    assert( x[0] == 4 );

    y = x.dup;

    assert( x == y );

    y.addHead(6);

    int[10] y2;
    int k=0;
    foreach(int val; y) {
      y2[k++] = val;
    }
    assert( y2[0] == 6 );
    assert( y2[1] == 4 );
    assert( y2[2] == 3 );
    assert( y2[3] == 5 );

    int[] w2 = y.values;
    assert( w2[0] == 6 );
    assert( w2[1] == 4 );
    assert( w2[2] == 3 );
    assert( w2[3] == 5 );
    assert( w2.length == 4 );

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
    foreach(Deque!(int) itr; y) {
      y2[k++] = itr[0];
    }
    assert( y2[0] == 6 );
    assert( y2[1] == 4 );
    assert( y2[2] == 3 );
    assert( y2[3] == 5 );
  
    Deque!(int) y3 = y[2..4];
    assert( y3.length == 2 );
    assert( y3[0] == 3 );
    assert( y3[1] == 5 );

    y3[0] = 10;
    assert( y[2] == 10 );

    Deque!(char[]) c;
    c ~= "a";
    c ~= "a";
    c ~= "a";
    c ~= "a";
    assert( c.opIn("a") == c.head );
    assert( c.count("a") == 4 );
    for (int kk=3;kk<6000;kk++) {
      c ~= toString(kk);
      c ~= toString(kk+1);
      char[] res = c.takeHead();
      if (kk > 10) {
	assert( res == toString(kk/2) );
      }
    }

    // test addAfter, addBefore and remove
    Deque!(double) w;
    for (k=0;k<20;k++)
      w ~= k;
    w.remove(w[10..15]);
    assert( w.length == 15 );
    assert( w[10] == 15 );
    for (k=0;k<5;k++)
      w.addHead(k);
    w.remove(w[2..7]);
    assert( w.length == 15 );
    Deque!(double) w3;
    for (k=0;k<20;k++)
      w3 ~= k;
    w.addBefore(w[5..7],w3[10..15]);
    assert( w.length == 20 );
    assert( w[0] == 4 );
    foreach( double d; w) {
      version (MinTLVerboseUnittest) 
	printf(" %g",d);
    }
    version (MinTLVerboseUnittest) 
      printf("\n");
    assert( w[5] == 10 );

    // test sorting
    Deque!(int) s1,s2;
    s1.add(40,300,-20,100,400,200);
    s1.sort();
    s2.add(-20,40,100,200,300,400);
    assert( s1 == s2 );

    Deque!(double) s3;
    for (k=0;k<1000;k++) {
      s3 ~= 1.0*rand()/100000.0 - 500000.0;
    }
    s3.sort();
    for (k=0;k<999;k++) {
      assert( s3[k] <= s3[k+1] );
    }

    version (MinTLVerboseUnittest) 
      printf("finished mintl.deque unittest\n");
  }
}
