/** \file hashaa.d
 * \brief A hash-based associative array that maintains elements in insertion order
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.7.1
 */

module mintl.hashaa;

//debug = dHashAA; // can also pass at command line

private {
  import mintl.share;
  import mintl.sorting;
  import mintl.mem;
}

/** \class HashAA
 * \brief A hash-based associative array traversed in insertion order.
 *
 * A HashAA!(Key,Value) represents an associative array with keys of
 * type Key and values of type Value that maintains the inserted items
 * in a linked list sorted by insertion order. If <tt>key1</tt> is
 * inserted into the array before <tt>key2</tt> then <tt>key1</tt>
 * will appear before <tt>key2</tt> in foreach statements and in
 * iterator traversals.
 *
 * The optional ReadOnly parameter HashAA!(Key,Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter ArrayList!(Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct HashAA(Key,Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias HashAA     ContainerType;
  alias HashAA     SliceType;
  alias Value      ValueType;
  alias Key        IndexType;
  alias Key        SortType;
  alias ReadOnly   isReadOnly;

  /** Get the kays in the array. The operation is O(n) where n is the number of
   * elements in the array.
   */
  Key[] keys() {
    Key[] res;
    if (head_ is null) return res;
    res.length = length;
    size_t n = 0;
    foreach(Key k,Value v;*this) {
      res[n++] = k;
    }
    return res;
  }

  /** Get the values in the array. The operation is O(n) where n is
   * the number of elements in the array.
   */
  Value[] values() {
    Value[] res;
    if (head_ is null) return res;
    res.length = length;
    size_t n = 0;
    foreach(Key k,Value v;*this) {
      res[n++] = v;
    }
    return res;
  }

  /** Property for the default value of the array when a key is missing. */
  void missing(Value val) {
    if (data.length == 0)
      initDataArray();
    data[0].val = val;
  }
  Value missing() {
    if (data.length == 0)
      return Value.init;
    return data[0].val;
  }

  /** Length of array. The operation is O(n) where n is the number of
   * elements in the array.
   */
  size_t length() { 
    if (head_ is null) return 0;
    if (head_.prev is null && tail_.next is null) return dlength();
    Node* t = head_;
    int n = 1;
    while (t !is null && t !is tail_) {
      t = t.next;
      ++n;
    }
    return n;
  }

  /** Return true if array is empty.   */
  bool isEmpty() { 
    return head_ is null;
  }

  private void initDataArray() {
    size_t s = prime_list[0]+1;
    static if (is(Alloc == GCAllocator)) {
      data.length = s;
    } else {
      Node** p = cast(Node**)Alloc.malloc((Node*).sizeof*s);
      data = p[0 .. s];
    }
    data[0] = allocNode;
    data[0].len = 0;
  }

  private enum {InsertOnMiss, ThrowOnMiss, NullOnMiss}

  // helper functions for indexing. 
  private Node** getNode(Key key, int failureAction) {
    Node* t;
    TypeInfo ti = typeid(Key);
    uint hash = ti.getHash(&key);
    if (data.length == 0) {
      switch (failureAction) {
      case InsertOnMiss:
	initDataArray();
	break;
      case ThrowOnMiss:
      GetActionThrow:
	throw new IndexOutOfBoundsException("Key not in container");
      case NullOnMiss:
	return null;
      }
    }
    uint i = (hash % (data.length-1))+1;
    Node**p = &data[i];
    while (*p !is null) {
      if ((*p).hash == hash && ti.equals(&(*p).key,&key)) {
	// found key
	return p;
      }
      p = &(*p).nextHash;
    }
    if (failureAction == ThrowOnMiss) {
      goto GetActionThrow;
    } else if (failureAction == NullOnMiss) {
      return null;
    }
    // lookup Node
    *p = t = allocNode();
    t.hash = hash;
    t.key = key;
    if (head_ is null) {
      head_ = t;
      tail_ = t;
    } else {
      link(tail_,t);
      tail_ = t;
    }
    data[0].len++;
    static if (!ReadOnly) {
      if (data[0].len > .75*data.length) {
	this.rehash();
	p = getNode(key,NullOnMiss);
      }
    }
    return p;
  }

  /** Find the element with a given key and return a pointer to the
   * value.  If the key is not in the array null is returned or if
   * throwOnMiss is true an exception is thrown.  The target array can
   * be a sub-array though the key may fall outside of the sub-array
   * range.
   */
  Value* get(Key key, bool throwOnMiss = false) {
    Node** t = getNode(key,throwOnMiss ? ThrowOnMiss : NullOnMiss);
    if (t) 
      return &(*t).val;
    else
      return null;
  }

  /** Create a sub-array from key a to b (exclusive).   */
  HashAA opSlice(Key a, Key b) {
    HashAA res;
    res.head_ = *getNode(a,ThrowOnMiss);
    res.tail_ = (*getNode(b,ThrowOnMiss)).prev; // will at least have a in there
    res.data = data;
    return res;
  }

  /** Create a sub-array from the first key in a to the last key in b (inclusive).   */
  HashAA opSlice(HashAA a, HashAA b) {
    HashAA res;
    res.head_ = a.head_;
    res.tail_ = b.tail_;
    res.data = data;
    return res;
  }

  /** Get a ReadOnly view of the container */
  .HashAA!(Key,Value,true,Alloc) readonly() {
    .HashAA!(Key,Value,true,Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .HashAA!(Key,Value,false,Alloc) readwrite() {
    .HashAA!(Key,Value,false,Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  static if (ReadOnly) {
  /** Duplicates the array.  The operation is O(n) where n is length.   */
    /* private bug
  HashAA dup() {
    .HashAA!(Key,Value,false) res;
    res.data.length = data.length;
    res.data[0] = cast(res.Node*)allocNode;
    res.data[0].len = 0;
    res.missing = missing;
    foreach(Key k,Value v;*this)
      res[k] = v;
    return res.readonly;
  }
    */
  } else {

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      foreach ( Node* t; data) {
	while (t) {
	  Node* next = t.nextHash;
	  Alloc.gcFree(t);
	  t = next;
	}
      }
      Alloc.free(data.ptr);
    }
    *this = HashAA.init;
  }

  /** Duplicates the array.  The operation is O(n) where n is length.   */
  HashAA dup() {
    HashAA res;
    res.data.length = data.length;
    res.data[0] = allocNode;
    res.data[0].len = 0;
    res.missing = missing;
    foreach(Key k,Value v;*this) {
      res[k] = v;
    }
    return res;
  }

  /** Rehash the array.   */
  HashAA rehash() {
    uint k;
    uint len = data.length;
    if (len == 0) return *this;
    for (k=0;k<prime_list.length;k++) {
      if (prime_list[k] > len) 
	break;
    }
    Node* n = data[0];
    size_t s = prime_list[k]+1;
    static if (is(Alloc == GCAllocator)) {
      data = new Node*[s];
    } else {
      Node** p = cast(Node**)Alloc.malloc((Node*).sizeof * s);
      data = p[0 .. s];
    }
    data[0] = n;
    Node* t = head_;
    while (t) {
      uint i = (t.hash %(data.length-1))+1;
      t.nextHash = data[i];
      data[i] = t;
      t = t.next;
    }
    return *this;
  }

  /** Find a key in the array and return a pointer to the associated value.
   * Insert the key and initialize with Value.init if the key is not
   * in the array.
   */
  Value* put(Key key) {
    debug (dHashAA) printf("put %d\n",key);
    Node* t = *getNode(key, InsertOnMiss);
    return &t.val;
  }

  /** Store a value with a key, overwriting any previous value.  The
   * target array can be a sub-array though the key may fall outside of the
   * sub-array range.
   */
  void opIndexAssign(Value val, Key key) {
    Node* t = *getNode(key, InsertOnMiss);
    t.val = val;
  }
  
  // helper for remove/take
  private Node* takeHelper(Key key) {
    Node** p = getNode(key,NullOnMiss);
    if (!p) return null;
    Node* n = *p;
    if (n is head_)
      head_ = n.next;
    if (n is tail_)
      tail_ = n.prev;
    link(n.prev, n.next);
    *p = n.nextHash;
    return n;
  }

  /** Remove a key from the array. The target array can be a sub-array though
   * the key may fall outside of the sub-array range.
   */
  void remove(Key key) {
    Node* n = takeHelper(key);
    if (n) {
      static if (is(Alloc == GCAllocator)) {
	static if (Node.sizeof < AllocBlockCutoff) {
	  n.next = data[0].next;
	  data[0].next = n;
	  n.prev = null;
	  n.val = Value.init;
	  n.key = Key.init;
	}
      } else {
	Alloc.gcFree(n);
      }
      data[0].len--;
    }
  }

  /** Remove the value stored with the given key and return it, if present. 
   * If not present return the missing default.
   */
  Value take(Key key) {
    Node* n = takeHelper(key);
    if (!n) return missing;
    Value val = n.val;
    static if (is(Alloc == GCAllocator)) {
      static if (Node.sizeof <= AllocBlockCutoff) {
	n.next = data[0].next;
	data[0].next = n;
	n.val = Value.init;
	n.key = Key.init;
	n.prev = null;
      }
    } else {
      Alloc.gcFree(n);
    }
    data[0].len--;
    return val;
  }

  /** Remove a sub-array from the array. The operation is O(max(log(m),n))
   * where m is the size of the target array and n is the number of
   * elements in the sub-array.
   */
  void remove(HashAA subarray) {
    if (subarray.head_ is subarray.tail_) {
      remove(subarray.key);
    } else {
      Key[] keylist = subarray.keys;
      foreach(Key key;keylist)
	remove(key);
    }
  }

  mixin MAddAA!(HashAA); // mixin add function
  
  } // !ReadOnly

  private void link(Node* a, Node* b) {
    if (a) a.next = b;
    if (b) b.prev = a;
  }

  // remove extra capacity
  void trim() {
    if (data.length > 0 && data[0])
      data[0].next = null;
  }

  // Parameters for controlling block allocations
  private const int AllocBlockSize = 10;   // number of nodes in block
  private const int AllocBlockCutoff = 96; // max node size to allow blocks

  private Node* allocNode() {
    Node* p;
    static if (is(Alloc == GCAllocator)) {
      static if (Node.sizeof > AllocBlockCutoff) {
	return new Node;
      } else {
	if (data[0] is null) return new Node;
	p = data[0].next;
	if (p) {
	  data[0].next = p.next;
	  p.next = null;
	  return p;
	}
	p = (new Node[AllocBlockSize]).ptr;
	for (int k=1;k<AllocBlockSize-1;k++)
	  p[k].next = &p[k+1];
	data[0].next = &p[1];
	return &p[0];
      }
    } else {
      p = cast(Node*)Alloc.gcMalloc(Node.sizeof);
    }
    return p;
  }

  /** Find the element with a given key and return the value.  If the
   * key is not in the map the default for the array is returned.  The
   * target array can be a sub-array though the key may fall outside
   * of the sub-array range.
   */
  Value opIndex(Key key) {
    Value* t = get(key);
    if (t)
      return *t;
    else
      return missing;
  }

  /** Returns the value of a one-item array.   */
  Value value() {
    if (head_ is null && tail_ is null)
      return Value.init;
    return head_.val;
  }

  /** Returns the key of a one-item array.   */
  Key key() {
    if (head_ is null && tail_ is null)
      return Key.init;
    return head_.key;
  }

  /** Return a one-item slice of the head (oldest insertion).   */
  HashAA head() {
    HashAA res = *this;
    res.tail_ = res.head_;
    return res;
  }

  /** Return a one-item slice of the tail (more recent insertion).   */
  HashAA tail() {
    HashAA res = *this;
    res.head_ = res.tail_;
    return res;
  }

  /** Move a slice by n. By default moves to the next item.   */
  void next(int n = 1, int end = 0) {
    void doNext(inout Node* node, int m) {
      while (m--)
	node = node.next;
    }
    void doPrev(inout Node* node, int m) {
      while (m--)
	node = node.prev;
    }
    if (n > 0) {
      if (end >= 0)
	doNext(tail_,n);
      if (end <= 0)
	doNext(head_,n);
    } else {
      n = -n;
      if (end >= 0)
	doPrev(tail_,n);
      if (end <= 0)
	doPrev(head_,n);
    }
  }

  /** Test for equality of two arrays.  The operation is O(n) where n
   * is length of the array.
   */
  int opEquals(HashAA c) {
    Node* i = head_;
    Node* j = c.head_;
    Node* end = tail_;
    Node* cend = c.tail_;
    TypeInfo ti_k = typeid(Key);
    TypeInfo ti_v = typeid(Value);
    int do_test(Node*p1,Node*p2) {
      if (!ti_k.equals(&p1.key,&p2.key))
	return 0;
      if (!ti_v.equals(&p1.val,&p2.val))
	return 0;
      return 1;
    }
    while (i !is null && j !is null) {
      if (!do_test(i,j)) 
	return 0;
      if (i is end || j is cend) {
	return (i is end && j is cend);
      }
      i = i.next;
      j = j.next;
    } 
    return (i is null && j is null);
  }

  /** Test if a key is in the array. The target array can be a sub-array
   * but the key may fall outside of the sub-array range.
   */
  bool contains(Key key) {
    return get(key) !is null;
  }

  /** Test if a key is in the array and set value if it is.   */
  bool contains(Key key,out Value value) {
    Value* node = get(key);
    if (node)
      value = *node;
    return node !is null;
  }

  /** Iterate over the array calling delegate to perform an action.  A
   * one-element sub-array is passed to the delegate.
   */
  int opApplyNoKeyStep(int delegate(inout Value val) dg, int step = 1) {
    int dg2(inout HashAA itr) {
      Value value = itr.value;
      return dg(value);
    }
    return opApplyIterStep(&dg2,step);
  }

  /** Iterate over the array calling delegate to perform an action.  A
   * one-element sub-array is passed to the delegate.
   */
  int opApplyWithKeyStep(int delegate(inout Key key, inout Value val) dg, 
			 int step = 1) {
    int dg2(inout HashAA itr) {
      Key key = itr.key;
      Value value = itr.value;
      return dg(key,value);
    }
    return opApplyIterStep(&dg2,step);
  }

  /** Iterate over the array calling delegate to perform an action.  A
   * one-element sub-array is passed to the delegate.
   */
  int opApplyIterStep(int delegate(inout HashAA itr) dg,int step=1) {
    int res = 0;
    HashAA itr;
    Node* x = step>0?head_:tail_;
    Node* end = step>0?tail_:head_;
    while (x !is null) {
      itr.head_ = itr.tail_ = x;
      res = dg(itr);
      if (res || x is end) return res;
      x = step>0?x.next:x.prev;
    }
    return res;
  }

  /** Iterate backwards over the array (from last to first key). The target
   *  array can be a sub-array.  This should only be called as the
   *  iteration parameter in a <tt>foreach</tt> statement
   */
  LAReverseIter!(Key,Value,ReadOnly,Alloc) backwards() {
    LAReverseIter!(Key,Value,ReadOnly,Alloc) res;
    res.list = this;
    return res;
  }

  /**  Helper functions for opApply   */
  mixin MOpApplyImpl!(HashAA);
  alias opApplyNoKey opApply;
  alias opApplyWithKey opApply;
  alias opApplyIter opApply;

  Node* getHead(){return head_;}
  Node* getTail(){return tail_;}
  mixin MSequentialSort!(HashAA, getHead,getTail);
  void sort(int delegate(Key*a, Key*b) cmp = null) {
    Node* newhead, newtail;
    dosort(newhead,newtail,cmp);
    head_ = newhead;
    tail_ = newtail;
  }

  private {
    struct Node {
      Node* next, prev, nextHash;
      union {
	uint len;
	uint hash;
      }
      Key key;
      Value val;
      Key* sortLookup(){return &key;}
    }
    Node*[] data;
    Node* head_, tail_;
  }

  private uint  dlength() { return data[0].len; }

  // size primes from aaA.d and planetmath.org
  private static uint[] prime_list = 
    [97u,         389u,       1543u,       6151u,
     24593u,      98317u,     393241u,     1572869u,
     6291469u,    25165843u,  100663319u,  402653189u,
     1610612741u, 4294967291u
  ];
}

// internal helper struct for backwards iteration
struct LAReverseIter(Key,Value,bit ReadOnly,Alloc) {
  mixin MReverseImpl!(HashAA!(Key,Value,ReadOnly,Alloc));
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;
version (MinTLUnittest) {
  private import std.random;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.hashaa unittest\n");

    HashAA!(int,int) m;
    m[4] = 100;
    m[-10] = 200;
    m[17] = 300;
    assert( m.length == 3 );
    assert( m[-10] == 200 );

    HashAA!(int,int) mm;
    mm.add(4,100, -10,200, 17,300);
    assert( m == mm );

    // test foreach
    int[] res;
    res.length = 3;
    int n=0;
    foreach(int val; m) {
      res[n++] = val;
    }
    assert( res[0] == 100 );
    assert( res[1] == 200 );
    assert( res[2] == 300 );

    // test removing an item
    m.remove(-10);
    n = 0;
    foreach(int val; m) {
      res[n++] = val;
    }
    assert( res[0] == 100 );
    assert( res[1] == 300 );

    // test assigning to an item already in array
    m[22] = 400;
    m[17] = 500;
    n = 0;
    foreach(int val; m) {
      res[n++] = val;
    }
    assert( res[0] == 100 );
    assert( res[1] == 500 );
    assert( res[2] == 400 );

    // test backwards foreach
    n = 0;
    foreach(int k,int val; m.backwards()) {
      res[n++] = val;
    }
    assert( res[0] == 400 );
    assert( res[1] == 500 );
    assert( res[2] == 100 );

    // test slicing
    HashAA!(int, int) m2 = 
      HashAA!(int,int).make(400,4,100,1,500,5,300,3,
			    200,2,600,6);
    HashAA!(int, int) m3;
    m3 = m2[500 .. 600];
    assert( m3.length == 3 );
    n = 0;
    foreach(int k,int val; m3) {
      res[n++] = val;
    }
    assert( res[0] == 5 );
    assert( res[1] == 3 );
    assert( res[2] == 2 );

    // test keys
    int[] keys = m3.keys;
    assert( keys[0] == 500 );
    assert( keys[1] == 300 );
    assert( keys[2] == 200 );

    // test rehash
    for (int k=0; k<1000; k++)
      m3[k] = k;
    HashAA!(int,int) m4 = m3.rehash;
    assert( m4 == m3 );

    // test simple sorting
    HashAA!(int,int) s1,s12;
    s1.add(40,1,300,2,-20,3,100,4,400,5,200,6);
    s12 = s1.dup;
    s1.sort();
    assert( s1 == HashAA!(int,int).make(-20,3,40,1,100,4,200,6,300,2,400,5) );
    // sort a slice in-place
    HashAA!(int,int) slice1 = s12[300 .. 200];
    slice1.sort();
    assert( s12 == HashAA!(int,int).make(40,1,-20,3,100,4,300,2,400,5,200,6));

    // test a large sort with default order
    HashAA!(double,int) s3;
    for (int k=0;k<1000;k++) {
      s3[1.0*rand()/100000.0 - 500000.0] = k;
    }
    HashAA!(double,int) s4 = s3.dup;
    s3.sort();
    double[] keys2 = s3.keys;
    for (int k=0;k<999;k++) {
      assert( keys2[k] <= keys2[k+1] );
    }
    // test a large sort with custom order
    int cmp(double*x,double*y){return *x>*y?-1:*x==*y?0:1;}
    s4.sort(&cmp);
    keys2 = s4.keys;
    for (int k=0;k<999;k++) {
      assert( keys2[k] >= keys2[k+1] );
    }

    version (MinTLVerboseUnittest) 
      printf("finished mintl.hashaa unittest\n");
  }
}
