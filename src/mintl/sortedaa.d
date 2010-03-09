/** \file sortedaa.d
 * \brief A sorted associative array.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * The red-black tree code is by Thomas Niemann.
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.7.1
 */

module mintl.sortedaa;

private import mintl.share; // for mixins
import mintl.mem;

// debug = dSortedAA; // can also pass at command line
//debug(dSortedAA) {
//  private import std.stdio;
//}

/** \class CompareFcnSetException
 * \brief An exception thrown when attempting to set the compare
 * function twice. In particular it cannot be set on a non-empty
 * SortedAA.
 */
class CompareFcnSetException: Exception {
  this(char[] str) { super(str); }
  this() { super("Cannot set the comparison function twice"); }
}

/** \class SortedAA
 * \brief A sorted associative array.
 *
 * A SortedAA!(Key,Value) represents a sorted associative array with
 * keys of type Key and values of type Value.  A sorted associative
 * array is similar to a builtin associative array except accessing an
 * elements is O(log(n)), where n is the number of elements in the
 * array, instead of O(1) and the elements are sorted by key. Any
 * operation that is not O(log(n)) will explicitly have the
 * performance behavior documented. 
 *
 * The array is sorted by default according to the key's TypeInfo compare
 * function. To use a custom key order call the CompareFcn property setter
 * with a delegate of the form int delegate(Key* a, Key* b). The comparison
 * function cannot be set after any elements are inserted.
 *
 * The optional ReadOnly parameter SortedAA!(Key,Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter SortedAA!(Key,Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct SortedAA(Key,Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias SortedAA   ContainerType;
  alias SortedAA   SliceType;
  alias Value      ValueType;
  alias Key        IndexType;
  alias ReadOnly   isReadOnly;

  /** Get a ReadOnly view of the container */
  .SortedAA!(Key,Value,true) readonly() {
    .SortedAA!(Key,Value,true) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .SortedAA!(Key,Value,false) readwrite() {
    .SortedAA!(Key,Value,false) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get the kays in the array. The operation is O(n) where n is the number of
   * elements in the array.
   */
  Key[] keys() {
    Key[] res;
    foreach(Key k,Value v;*this)
      res ~= k;
    return res;
  }

  /** Get the values in the array. The operation is O(n) where n is the number of
   * elements in the array.
   */
  Value[] values() {
    Value[] res;
    foreach(Key k,Value v;*this)
      res ~= v;
    return res;
  }

  /** Property for the default value of the array when a key is missing. */
  void missing(Value val) {
    fixupShared();
    shared_.missing = val;
  }
  Value missing() {
    if (!shared_)
      return Value.init;
    return shared_.missing;
  }

  /** Length of array. The operation is O(n) where n is the number of
   * elements in the array.
   */
  size_t length() { 
    size_t len = 0;
    foreach(Value val; *this) 
      len++;
    return len;
  }

  /** Test if array is empty.   */
  bool isEmpty() { 
    return shared_ is null || shared_.root is null;
  }

  static if (ReadOnly) {

  /** Duplicates an array.   */
  SortedAA dup() {
    .SortedAA!(Key,Value,false) res;
    if (shared_) {
      if (shared_.cmpFcn)
	res.compareFcn = shared_.cmpFcn;
      res.missing = missing;
    }
    foreach(Key k,Value v;*this)
      res[k] = v;
    return res.readonly;
  }

  } else {

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      if (shared_) {
	void freeNode(Node*p) {
	  if(p) {
	    freeNode(p.left);
	    freeNode(p.right);
	    Alloc.gcFree(p);
	  }
	}
	freeNode(shared_.root);
	Alloc.gcFree(shared_);
      }
    }
    *this = SortedAA.init;
  }

  /** Remove a key from the array. The target array can be a sub-array though
   * the key may fall outside of the sub-array range. The value stored for
   * the key is returned, if present.
   */
  Value take(Key key) {
    //    debug(dSortedAA) writefln("getAndRemove: %s",key);
    Node* node = getNode(key,NullOnMiss);
    if (!node) return missing;
    Value value = node.val;
    deleteNode(node);
    return value;
  }

  /** Remove a key from the array. The target array can be a sub-array though
   * the key may fall outside of the sub-array range.
   */
  void remove(Key key) {
    //    debug(dSortedAA) writefln("remove: %s",key);
    deleteNode(getNode(key,NullOnMiss));
  }

  /** Remove a sub-array from the array. The operation is O(max(log(m),n))
   * where m is the size of the target array and n is the number of
   * elements in the sub-array.
   */
  void remove(SortedAA subarray) {
    if (subarray.head_ is subarray.tail_) {
      deleteNode(subarray.head_);
    } else {
      Key[] keylist = subarray.keys;
      foreach(Key key;keylist)
	remove(key);
    }
  }

  /** Duplicates an array.   */
  SortedAA dup() {
    SortedAA res;
    if (shared_) {
      if (shared_.cmpFcn)
	res.compareFcn = shared_.cmpFcn;
      res.missing = missing;
    }
    foreach(Key k,Value v;*this)
      res[k] = v;
    return res;
  }

  } // !ReadOnly

  /** signature for a custom comparison function */
  alias int delegate(Key* a, Key* b) CompareFcn;

  /** Set custom comparison function. If the array is non-empty or the
   * comparison function has already been set a CompareFcnSetException
   * is thrown.
   */
  void compareFcn(CompareFcn cmp) {
    allocShared();
    if (shared_.cmpFcn !is null)
      throw new CompareFcnSetException();
    else
      shared_.cmpFcn = cmp;
  }

  /** Find (and insert if not present) the element with a given key
   * and return the value. The target array can be a sub-array though
   * the key may fall outside of the sub-array range.
   */
  Value opIndex(Key key) {
    Node* t = getNode(key,NullOnMiss);
    if (t)
      return t.val;
    else
      return missing;
  }

  /** Store a value with a key, overwriting any previous value.  The
   * target array can be a sub-array though the key may fall outside of the
   * sub-array range.
   */
  void opIndexAssign(Value val, Key key) {
    Node* t = getNode(key,InsertOnMiss);
    t.val = val;
  }

  /** Returns the value of the first item of a slice. In particular gets
   * the value of a one-item slice.
   */
  Value value() {
    if (head_ is null && tail_ is null)
      return Value.init;
    return head_.val;
  }

  /** Returns the key of the first item of a slice. In particular gets
   * the key of a one-item slice.
   */
  Key key() {
    if (head_ is null && tail_ is null)
      return Key.init;
    return head_.key;
  }

  /** Return the start of the sorted items (the min).   */
  SortedAA head() {
    Node* node = head_ is null ? minNode() : head_;
    SortedAA res;
    res.shared_ = shared_;
    res.head_ = res.tail_ = node;
    return res;
  }

  /** Return the end of the sorted items (the max).   */
  SortedAA tail() {
    Node* node = tail_ is null ? maxNode() : tail_;
    SortedAA res;
    res.shared_ = shared_;
    res.head_ = res.tail_ = node;
    return res;
  }

  /** Return a one-item slice of the item less than key   */
  SortedAA to(Key key) {
    SortedAA res;
    res.shared_ = shared_;
    res.head_ = res.tail_ = lookupSide(key,false);
    return res;
  }

  /** Return a one-item slice of the item greater than or equal to key   */
  SortedAA from(Key key) {
    SortedAA res;
    res.shared_ = shared_;
    res.head_ = res.tail_ = lookupSide(key,true);
    return res;
  }

  /** Move a slice towards the head or tail by n items. If n is 
   * negative the slice moves towards the head. A positive end is
   * the tail, negative the head and 0 is both. By default moves to
   * the next item.
   */
  void next(int n = 1, int end = 0) {
    void doNext(inout Node* node, int m) {
      while (m--)
	node = nextNode(node);
    }
    void doPrev(inout Node* node, int m) {
      while (m--)
	node = prevNode(node);
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

  /** Find the element with a given key and return a pointer to the
   * value.  If the key is not in the array null is returned or if
   * throwOnMiss is true an exception is thrown.  The target array can
   * be a sub-array though the key may fall outside of the sub-array
   * range.
   */
  Value* get(Key key, bool throwOnMiss = false) {
    Node* t = getNode(key,throwOnMiss ? ThrowOnMiss : NullOnMiss);
    if (t)
      return &t.val;
    else
      return null;
  }

  /** Find a key in the array and return a pointer to the associated value.
   * Insert the key and initialize with Value.init if the key is not
   * in the array.
   */
  Value* put(Key key) {
    Node* t = getNode(key, InsertOnMiss);
    return &t.val;
  }

  /** Create a slice from the head of a to the tail in b (inclusive).   */
  SortedAA opSlice(SortedAA a, SortedAA b) {
    SortedAA res;
    res.head_ = a.head_ is null ? minNode() : a.head_;
    res.tail_ = b.tail_ is null ? maxNode() : b.tail_;
    res.shared_ = shared_;
    return res;
  }

  /** Create a sub-array from key a to b (exclusive).   */
  SortedAA opSlice(Key a, Key b) {
    return (*this)[from(a) .. to(b)];
  }

  /** Create a sub-array from slice a to key b (exclusive).   */
  SortedAA opSlice(SortedAA a, Key b) {
    return (*this)[a .. to(b)];
  }
  /** Create a sub-array from key a to slice b (inclusive).   */
  SortedAA opSlice(Key a, SortedAA b) {
    return (*this)[from(a) .. b];
  }

  /** Test for equality of two arrays.  The operation is O(n) where n
   * is length of the array.
   */
  int opEquals(SortedAA c) {
    fixupShared();
    c.fixupShared();
    Node* i = head_ ? head_ : minNode();
    Node* j = c.head_ ? c.head_ : c.minNode();
    Node* end = tail_ ? tail_ : maxNode();
    Node* cend = c.tail_ ? c.tail_ : c.maxNode();
    TypeInfo ti_k = typeid(Key);
    TypeInfo ti_v = typeid(Value);
    int do_test(Node*p1,Node*p2) {
      if (p1 is null && p2 is null)
	return 1;
      if ((p1 is null && p2 !is null) ||
	  (p1 !is null && p2 is null))
	return 0;
      if (!ti_k.equals(&p1.key,&p2.key))
	return 0;
      if (!ti_v.equals(&p1.val,&p2.val))
	return 0;
      return 1;
    }
    while (i !is end && j !is cend) {
      if (!do_test(i,j)) 
	return 0;
      i = nextNode(i);
      j = c.nextNode(j);
    } 
    return do_test(i,j);
  }

  /** Test if a key is in the array. The target array can be a sub-array
   * but the key may fall outside of the sub-array range.
   */
  bool contains(Key key) {
    Value* node = get(key);
    return node !is null;
  }

  /** Test if a key is in the array and set value if it is.   */
  bool contains(Key key,out Value value) {
    Value* node = get(key);
    if (node)
      value = *node;
    return node !is null;
  }

  /** Iterate over the array calling delegate to perform an action.
   * The value is passed to the delegate.
   */
  int opApplyNoKeyStep(int delegate(inout Value val) dg, int step=1) {
    int dg2(inout SortedAA itr) {
      Value value = itr.value;
      return dg(value);
    }
    return opApplyIterStep(&dg2,step);
  }

  /** Iterate over the array calling delegate to perform an action.
   * The key and value are passed to the delegate.
   */
  int opApplyWithKeyStep(int delegate(inout Key key, inout Value val) dg, 
			 int step = 1) {
    int dg2(inout SortedAA itr) {
      Key key = itr.key;
      Value value = itr.value;
      return dg(key,value);
    }
    return opApplyIterStep(&dg2,step);
  }

  /** Iterate over the array calling delegate to perform an action.  A
   * one-element sub-array is passed to the delegate.
   */
  int opApplyIterStep(int delegate(inout SortedAA itr) dg,int step=1) {
    SortedAA itr;
    itr = *this;
    int res;
    if (shared_ is null) return 0;
    Node* i = head_ ? head_ : minNode();
    Node* j = tail_ ? tail_ : maxNode();
    Node* x = step>0?i:j;
    Node* end = step>0?j:i;
    while (x !is null) {
      itr.head_ = itr.tail_ = x;
      res = dg(itr);
      if (res || x is end) return res;
      x = step>0?nextNode(x):prevNode(x);
    }
    return res;
  }

  /** Iterate backwards over the array (from last to first key). This
   * should only be called as the iteration parameter in a
   * <tt>foreach</tt> statement
   */
  SortedAAReverseIter!(Key,Value,ReadOnly,Alloc) backwards() {
    SortedAAReverseIter!(Key,Value,ReadOnly,Alloc) res;
    res.list = this;
    return res;
  }

  /**  Helper functions for opApply   */
  mixin MOpApplyImpl!(SortedAA);
  alias opApplyNoKey opApply;
  alias opApplyWithKey opApply;
  alias opApplyIter opApply;
  mixin MAddAA!(SortedAA); // mixin add function

  // End of public interface

  private {
    enum Color:int { Red, Black }
    // share some data between array and sub-arrays to make updating
    // easier and shrink the SortedAA footprint.
    struct SharedArrayData {
      Node* root;
      CompareFcn cmpFcn;
      Value missing;
      Node* freelist;
    }
    struct Node {
      Node* left, right, parent;
      Color color;
      Key key;
      Value val;
    }
    SharedArrayData *shared_;
    Node* head_, tail_;
  }

  debug(dSortedAA) {
    private void dumpTree(Node* x, char[] str,int indent) {
      if (x !is null) {
	int n = indent;
	while (n--) printf("  ");
	printf("%.*s %p: %d %.*s\n",str,x,x.color,x.key);
	dumpTree(x.left,"left",indent+1);
	dumpTree(x.right,"right",indent+1);
      }
    }
  }

  // lookup the smallest item greater than or equal to key (from)
  // or lookup the largest item less than key
  Node* lookupSide(Key key, bool from) {
    Node* current;
    Node* parent;
    fixupShared();
    current = shared_.root;
    parent = current;
    int cmpVal = 0;
    CompareFcn cmp = shared_.cmpFcn;
    while (current !is null) {
      cmpVal = cmp(&key,&current.key);
      if (cmpVal == 0) {
	return from?current:prevNode(current);
      }
      parent = current;
      current = cmpVal < 0 ? current.left : current.right;
    }
    if (!parent) throw new Exception("Invalid Index");
    if (from)
      return cmpVal<0?prevNode(parent):parent; 
    else
      return cmpVal>0?nextNode(parent):parent; 
  }

  // initialize shared_ data if null
  private void allocShared() {
    if (shared_ is null) {
      static if (is(Alloc == GCAllocator)) {
	shared_ = new SharedArrayData;
      } else {
	shared_ = cast(SharedArrayData*)Alloc.gcMalloc(SharedArrayData.sizeof);
	*shared_ = SharedArrayData.init;
      }
    }
  }

  // initialize shared_ data if null and initialize cmpFcn
  private void fixupShared() {
    allocShared();
    if (shared_.cmpFcn is null) {
      TypeInfo ti = typeid(Key);
      shared_.cmpFcn = cast(CompareFcn)&ti.compare;
    }
  }

  // return the next largest node or null if none
  // used when we can't traverse the whole tree
  private Node* nextNode(Node* x) {
    if (x.right !is null) {
      x = x.right;
      while (x.left != null) x = x.left;
    } else {
      while (x.parent !is null && x.parent.right == x) 
	x = x.parent;
      if (x.parent !is null && x.parent.left == x) 
	x = x.parent;
      else
	x = null;
    }
    return x;
  }

  // return the previous node or null if none
  // used when we can't traverse the whole tree
  private Node* prevNode(Node* x) {
    if (x.left !is null) {
      x = x.left;
      while (x.right != null) x = x.right;
    } else {
      while (x.parent !is null && x.parent.left == x) 
	x = x.parent;
      if (x.parent !is null && x.parent.right == x) 
	x = x.parent;
      else
	x = null;
    }
    return x;
  }

  // fixup Red-Black invariant
  private void rotateLeft(Node* x) {
    Node* y = x.right;
    assert( y !is null );
    x.right = y.left;
    if (y.left !is null)
      y.left.parent = x;
    y.parent = x.parent;
    if (x.parent !is null) {
      if (x is x.parent.left)
	x.parent.left = y;
      else
	x.parent.right = y;
    } else {
      shared_.root = y;
    }
    y.left = x;
    if (x !is null) x.parent = y;
  }

  // fixup Red-Black invariant
  private void rotateRight(Node* x) {
    Node* y = x.left;
    assert( y !is null );
    x.left = y.right;
    if (y.right !is null)
      y.right.parent = x;
    y.parent = x.parent;
    if (x.parent !is null) {
      if (x is x.parent.right) 
	x.parent.right = y;
      else
	x.parent.left = y;
    } else {
      shared_.root = y;
    }
    y.right = x;
    if (x !is null) x.parent = y;
  }

  // fixup Red-Black invariant after an insert
  private void insertFixup(Node* x) {
    Node* root = shared_.root;
    while (x !is root && x.parent.color == Color.Red) {
      debug(dSortedAA) printf("fixing up parent %p\n",x.parent);
      if (x.parent is x.parent.parent.left) {
	Node* y = x.parent.parent.right;
	if (y !is null && y.color == Color.Red) {
	  x.parent.color = Color.Black;
	  y.color = Color.Black;
	  x.parent.parent.color = Color.Red;
	  x = x.parent.parent;
	} else {
	  if (x is x.parent.right) {
	    x = x.parent;
	    debug(dSortedAA) printf("rotating left %p\n",x);
	    rotateLeft(x);
	  }
	  x.parent.color = Color.Black;
	  x.parent.parent.color = Color.Red;
	  debug(dSortedAA) printf("rotating right1 %s\n",x.parent.parent);
	  rotateRight(x.parent.parent);
	}
      } else {
	Node* y = x.parent.parent.left;
	if (y !is null && y.color == Color.Red) {
	  x.parent.color = Color.Black;
	  y.color = Color.Black;
	  x.parent.parent.color = Color.Red;
	  x = x.parent.parent;
	} else {
	  if (x is x.parent.left) {
	    x = x.parent;
	    debug(dSortedAA) printf("rotating right %p\n",x);
	    rotateRight(x);
	  }
	  x.parent.color = Color.Black;
	  x.parent.parent.color = Color.Red;
	  debug(dSortedAA) printf("rotating left1 %p\n",x.parent.parent);
	  rotateLeft(x.parent.parent);
	}
      }
    }
    while (x.parent !is null)
      x = x.parent;
    x.color = Color.Black;
  }

  private enum {InsertOnMiss, ThrowOnMiss, NullOnMiss}

  // returns node for a given key - even if the key is ouside the
  // sub-array.
  private Node* getNode(Key key, int failureAction) {
    //    debug(dSortedAA) writefln("lookup %s",key);
    Node* current;
    fixupShared();
    current = shared_.root;
    Node* parent = null;
    int cmpVal = 0;
    CompareFcn cmp = shared_.cmpFcn;
    while (current !is null) {
      cmpVal = cmp(&key,&current.key);
      //      debug(dSortedAA) writefln("comparing %s %s got %s",key,current.key,cmpVal);
      if (cmpVal == 0) return current;
      parent = current;
      current = cmpVal < 0 ? current.left : current.right;
    }
    switch (failureAction) {
    case NullOnMiss: return null;
    case ThrowOnMiss: throw new IndexOutOfBoundsException("Key not in container");
    case InsertOnMiss: return insertNode(key, Value.init, parent, cmpVal);
    default: assert (false);
    }
  }

  // remove extra capacity
  void trim() {
    if (shared_)
      shared_.freelist = null;
  }

  // Parameters for controlling block allocations
  private const int NodeAllocBlockSize = 10; // number of nodes in block
  private const int AllocBlockCutoff = 96;   // max node size to allow blocks

  // helper function to allocate a node
  private Node* newNode() {
    static if (is(Alloc == GCAllocator)) {
      static if (Node.sizeof > AllocBlockCutoff) {
	return new Node;
      } else {
	if (shared_.freelist) {
	  Node* t = shared_.freelist;
	  shared_.freelist = t.left;
	  t.left = null;
	  return t;
	}
	Node[] block = new Node[NodeAllocBlockSize];
	for(int k=1;k<NodeAllocBlockSize-1;k++)
	  block[k].left = &block[k+1];
	shared_.freelist = &block[1];
	return &block[0];
      }
    } else {
      Node* p = cast(Node*)Alloc.gcMalloc(Node.sizeof);
      *p = Node.init;
      return p;
    }
  }

  // insert and return new node at the given parent
  private Node* insertNode(Key key, Value data, 
			     Node* parent, int cmpVal) {
    Node* x = newNode;
    x.key = key;
    x.val = data;
    x.parent = parent;
    x.color = Color.Red;
    if (parent !is null) {
      if (cmpVal < 0) {
	parent.left = x;
      } else {
	parent.right = x;
      }
    } else {
      shared_.root = x;
    }
    insertFixup(x);
    return x;
  }

  // fixup Red-Black invariant after a delete
  private void deleteFixup(Node* x) {
    Node* root = shared_.root;
    while (x !is root && x.color == Color.Black) {
      if (x is x.parent.left) {
	Node* w = x.parent.right;
	if (w !is null && w.color == Color.Red) {
	  w.color = Color.Black;
	  x.parent.color = Color.Red;
	  rotateLeft(x.parent);
	  w = x.parent.right;
	}
	assert( w !is null );
	if ((w.left is null || w.left.color == Color.Black) && 
	    (w.right is null || w.right.color == Color.Black)) {
	  w.color = Color.Red;
	  x = x.parent;
	} else {
	  if (w.right is null || w.right.color == Color.Black) {
	    w.left.color = Color.Black;
	    w.color = Color.Red;
	    rotateRight(w);
	    w = x.parent.right;
	  }
	  w.color = x.parent.color;
	  x.parent.color = Color.Black;
	  w.right.color = Color.Black;
	  rotateLeft(x.parent);
	  x = root;
	}
      } else {
	Node* w = x.parent.left;
	assert( w !is null );
	if (w.color == Color.Red) {
	  w.color = Color.Black;
	  x.parent.color = Color.Red;
	  rotateRight(x.parent);
	  w = x.parent.left;
	}
	assert( w !is null );
	if ((w.left is null || w.left.color == Color.Black) && 
	    (w.right is null || w.right.color == Color.Black)) {
	  w.color = Color.Red;
	  x = x.parent;
	} else {
	  if (w.left is null || w.left.color == Color.Black) {
	    w.right.color = Color.Black;
	    w.color = Color.Red;
	    rotateLeft(w);
	    w = x.parent.left;
	  }
	  w.color = x.parent.color;
	  x.parent.color = Color.Black;
	  w.left.color = Color.Black;
	  rotateRight(x.parent);
	  x = root;
	}
      }
    }
    x.color = Color.Black;
  }

  // get the miminum element of the array
  private Node* minNode() {
    Node* x = shared_.root;
    while (x !is null && x.left !is null) {
      x = x.left;
    }
    return x;
  }

  // get the maximum element of the array
  private Node* maxNode() {
    Node* x = shared_.root;
    while (x !is null && x.right !is null) {
      x = x.right;
    }
    return x;
  }

  // deletes a node from the array.
  // This routine should probably not copy node contents around to be
  // nice to other sub-arrays. Instead copy around pointers to parents
  // and children.
  private void deleteNode(Node* z) {
    Node* x,y;
    if (z is null) 
      return;
    debug(dSortedAA) printf("zleft %p right %p\n",z.left,z.right);
    if (z.left is null || z.right is null) {
      y = z;
    } else {
      y = z.right;
      while (y.left !is null) {
	y = y.left;
      }
    }
    debug(dSortedAA) printf("y.left %p y right %p\n",y.left,y.right);
    if (y.left !is null)
      x = y.left;
    else
      x = y.right;
    bool useTempX = x is null;
    Node tempX;
    if (useTempX) {
      debug(dSortedAA) printf("allocating tmpxnode\n");
      x = &tempX;
      x.color = Color.Black;
    }
    x.parent = y.parent;
    if (y.parent !is null) {
      if (y is y.parent.left)
	y.parent.left = x;
      else
	y.parent.right = x;
    } else {
      shared_.root = x;
    }
    if (y !is z) {
      debug(dSortedAA) printf("swapping %p with %p\n",y,z);
      z.key = y.key;
      z.val = y.val;
    }
    if (y.color == Color.Black) {
      deleteFixup(x);
    }
    if (useTempX) {
      // replace temporary "NIL" with nulls
      if (x is shared_.root)
	shared_.root = null;
      else if (x is x.parent.left)
	x.parent.left = null;
      else if (x is x.parent.right)
	x.parent.right = null;
    }
    static if (is(Alloc == GCAllocator)) {
      static if (Node.sizeof <= AllocBlockCutoff) {
	*y = Node.init;
	y.left = shared_.freelist;
	shared_.freelist = y;
      }
    } else {
      Alloc.gcFree(y);
    }
  }
}

// helper structure for backwards()
struct SortedAAReverseIter(Key,Value, bit ReadOnly, Alloc) {
  mixin MReverseImpl!(SortedAA!(Key,Value,ReadOnly,Alloc));
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;

version (MinTLUnittest) {
  private import std.random;
  private import std.string;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.sortedaa unittest\n");

    SortedAA!(int,int) m;
    m[4] = 100;
    //private bug
    //    assert( m.shared_.root !is null );
    //    assert( m.shared_.root.val == 100 );
    for (int k=1; k<1000; k++) {
      int key = std.random.rand()%30;
      if (m.contains(key))
	m.remove(key);
      else
	m[key] = 1;
    }
    SortedAA!(char[],char[]) m2;
    for (int k=1; k<1000; k++) {
      int key = rand()%300;
      m2[toString(key)] = toString(key);
    }
    char[] prev;
    foreach(char[] val; m2) {
      assert( val > prev );
      prev = val;
    }
    /* private bug
    SortedAA!(char[],char[]) m5 = m2;
    m5.head_ = m5.minNode();
    m5.tail_ = m5.maxNode();
    prev = "";
    foreach(char[] val; m5) {
      assert( val > prev );
      prev = val;
    }
    prev = m5.maxNode().val;
    foreach(char[] val; m5.backwards()) {
      assert( val <= prev );
      prev = val;
    }
    */
    SortedAA!(int,int) m3;
    m3.compareFcn = delegate int(int* a, int* b) {
      return *a-*b;
    };
    m3[10] = -100;
    m3[7] = 100;
    m3[-10] = 200;
    assert( m3.length == 3);
    assert( m3[7] == 100 );
    assert( m3[-10] == 200 );
    assert( m3[10] == -100 );

    SortedAA!(int,int) mm;
    mm.add(10,-100, 7,100, -10,200);
    assert( m3 == mm );
  
    SortedAA!(int,int) m3a = m3.dup;
    assert( m3a == m3 );
    assert( m3a !is m3 );
    assert( m3a.length == 3);
    assert( m3a[7] == 100 );
    assert( m3a[-10] == 200 );
    assert( m3a[10] == -100 );
  
    m3.remove(7);
    m3.remove(10);
    m3.remove(-10);
    //    assert( m3.shared_.root is null );

    int[] keys = m3a.keys;
    assert( keys[0] == -10 );
    assert( keys[1] == 7 );
    assert( keys[2] == 10 );

    // test slicing
    SortedAA!(char[],int) m8 = 
      SortedAA!(char[],int).make("a",100,"c",300,"d",400,"b",200,
				 "f",600,"e",500);
    SortedAA!(char[],int) msl,msl2,msl3;
    //    debug(dSortedAA)   m8.dumpTree(m8.shared_.root,"",0);
    msl = m8["b".."d"];
    msl2 = m8[m8.from("b123") .. m8.to("e")];
    assert( msl.length == 2 );
    //    assert( msl.head_.key == "b" );
    //    assert( msl.tail_.key == "c" );
    msl2 = m8["c".."f"];
    assert( msl2.length == 3 );
    //    assert( msl2.head_.key == "c" );
    //    assert( msl2.tail_.key == "e" );
    msl3 = m8[msl..msl2];
    assert( msl3.length == 4 );
    //    assert( msl3.head_.key == "b" );
    //    assert( msl3.tail_.key == "e" );
    m8.remove(msl2);
    assert( m8.length == 3 );
    debug(dSortedAA) printf("\nsize %d\n",m8.sizeof);

    SortedAA!(int,int,false,MallocNoRoots) mal;
    mal[10] = 20;
    mal[30] = 50;
    assert( mal[10] == 20 );
    assert( mal[30] == 50 );
    mal.clear();
    assert( mal.isEmpty );

    version (MinTLVerboseUnittest) 
      printf("starting mintl.sortedaa unittest\n");
  }
}
