/** \file slist.d
 * \brief A singly-linked list and circular singly-linked list.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.7.1
 */

module mintl.slist;

private import mintl.share; // for ~ and ~= and SNode
import mintl.mem;

// shared data structure between SList and CircularSList
private struct SNode(Value) {
  SNode* next;
  Value data;
}

/** Template for member functions common to SList and CircularSList */
template MCommonSList(alias head_, Container ) {

  /** Get the length of list. This operation is O(n) where n is
   * the resulting length.
   */
  size_t length() {
    Container.Node* p = head_;
    if (p is null) 
      return 0;
    size_t len = 1;
    while (p !is tail_) {
      p = p.next;
      len++;
    }
    return len;
  }

  /** Test if container is empty.   */
  bool isEmpty() { 
    return head_ is null;
  }

  /** helper function to check if the index is legal.  */
  void boundsCheck(Container.Node* p) {
    version (MinTLNoIndexChecking) {
    } else {
      if (p is null) {
	throw new IndexOutOfBoundsException();
      }
    }
  }

  /* Internal function to get the nth item of the list.   */
  package Container.Node* getNode(size_t n) {
    boundsCheck(head_);
    Container.Node* p = head_;
    while (n--) {
      p = p.next;
      boundsCheck(p);
    }
    return p;
  }

  /** Get the nth item in the list from head. The operation is O(n).
   * To efficiently access the tail of the list use the <tt>tail</tt>
   * property.
   * Indexing out of bounds throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  Container.ValueType opIndex(size_t n) {
    return getNode(n).data;
  }

  static if (!Container.isReadOnly) {

  /** Get a pointer to the nth item in the list from head. The
   * operation is O(n).  To efficiently access the tail of the list
   * use the <tt>tail</tt> property.  Indexing out of bounds throws an
   * IndexOutOfBoundsException unless version=MinTLNoIndexChecking is
   * set.
   */
  Container.ValueType* lookup(size_t n) {
    return &getNode(n).data;
  }

  /** Set the nth item in the list from head. The operation is O(n).
   * To efficiently access the tail of the list use the <tt>tail</tt>
   * property.
   * Indexing out of bounds throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  void opIndexAssign(Container.ValueType val, size_t n) {
    getNode(n).data = val;
  }

  } // !ReadOnly

  /** Iterates over the list from head to tail calling delegate to
   * perform an action. The value is passed to the delegate.
   */
  int opApplyNoKey(int delegate(inout Container.ValueType x) dg){
    int dg2(inout size_t count, inout Container.ValueType val) {
      return dg(val);
    }
    return opApplyWithKey(&dg2);
  }
  
  /** Iterates over the list from head to tail calling delegate to
   * perform an action. The index from 0 and the value are passed
   * to the delegate.
   */
  int opApplyWithKey(int delegate(inout size_t n, inout Container.ValueType x) dg){
    Container.Node* i = head_;
    Container.Node* end = tail_;
    int res = 0;
    size_t n = 0;
    while (i !is null) {
      res = dg(n, i.data);
      if (res || i is end) break;
      n++;
      i = i.next;
    } 
    return res;
  }

  /** Iterates over the list from head to tail calling delegate to
   * perform an action. A one-item sub-list is passed to the delegate.
   */
  int opApplyIter(int delegate(inout Container.SliceType n) dg){
    Container.Node* i = head_;
    Container.Node* end = tail_;
    int res = 0;
    Container.SliceType n;
    while (i !is null) {
      n.head_ = n.tail_ = i;
      res = dg(n);
      if (res || i is end) break;
      i = i.next;
    } 
    return res;
  }

  /** Test for equality of two lists.  The operation is O(n) where n
   * is length of the list.
   */
  int opEquals(Container c) {
    Container.Node* i = head_;
    Container.Node* j = c.head_;
    Container.Node* t = tail_;
    Container.Node* ct = c.tail_;
    TypeInfo ti = typeid(Container.ValueType);
    while (i !is null && j !is null) {
      if (!ti.equals(&i.data,&j.data))
	return 0;
      if (i is t && j is ct)
	return 1;
      i = i.next;
      j = j.next;
    } 
    return (i is null && j is null);
  }

  /** Compare two lists.   */
  int opCmp(Container c) {
    Container.Node* i = head_;
    Container.Node* j = c.head_;
    Container.Node* t = tail_;
    Container.Node* ct = c.tail_;
    TypeInfo ti = typeid(Container.ValueType);
    while (i !is null && j !is null) {
      int cmp = ti.compare(&i.data,&j.data);
      if (cmp)
	return cmp;
      if (i is t && j is ct)
	return 0;
      i = i.next;
      j = j.next;
    }
    if (i is null && j is null)
      return 0;
    else 
      return (i is null) ? -1 : 1;
  }

  /** Create a one-item slice of the head.   */
  Container.SliceType head() {
    return opSlice(0,1);
  }

  /** Return a one-item slice at the tail.   */
  Container.SliceType tail() {
    Container.SliceType res;
    res.head_ = res.tail_ = tail_;
    return res;
  }

  /** Create a sub-list from index a to b (exclusive). The operation is
   * O(max(a,b)).   */
  Container.SliceType opSlice(size_t a, size_t b) {
    Container.SliceType res;
    if (a != b) {
      res.head_ = getNode(a);
      Container.Node *v = res.head_;
      b = b-a-1;
      while (b--)
	v = v.next;
      res.tail_ = v;
    }
    return res;
  }

  /** Create a sub-list from the head of a to the tail of b (inclusive).  */
  Container.SliceType opSlice(Container.SliceType a, Container.SliceType b) {
    if (a.head_ is null)
      return b;
    if (b.head_ is null)
      return a;
    Container.SliceType res;
    res.head_ = a.head_;
    res.tail_ = b.tail_;
    return res;
  }

  /** Copies the list contents to an array.   */
  Container.ValueType[] values() {
    Container.ValueType[] buffer = new Container.ValueType[length()];
    foreach(size_t n, Container.ValueType val; *this) {
      buffer[n] = val;
    }
    return buffer;
  }
}

/** \class SList
 * \brief A singly-linked list.
 *
 * A SList!(Value) is a singly linked list of data of type Value. A
 * list is similar to a dynamic array except accessing an element in
 * the middle or near the end of the list is O(n) and appending to the
 * front or back is O(1). Any operation that is not constant-time will
 * explicitly have the performance behavior documented.
 *
 * A singly-linked list differs from a doubly-linked list in the speed
 * of accessing elements near the end of the list and the ability to
 * <tt>reverse</tt>, <tt>addBefore</tt> iterate <tt>backwards</tt> and
 * <tt>remove</tt> a sublist.  The only operations supported in the
 * middle of a singly-linked list are operations that modify the items
 * that follow the sublist. This prevents manipulations in one sublist
 * from invalidating an adjacent sublist.
 *
 * The optional ReadOnly parameter SList!(Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter SList!(Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct SList(Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias SList         ContainerType;
  alias SList         SliceType;
  alias Value         ValueType;
  alias size_t        IndexType;
  alias SNode!(Value) Node;
  alias ReadOnly      isReadOnly;

  const int NodeAllocationBlockSize = 10; // allocate 10 nodes at a time

  // private bug  private {
    Node* head_;   // head_ is first item
    Node* tail_;  // tail_ is last item
    //  }

  mixin MCommonSList!(head_, SList );

  SList getThis(){return *this;}
  mixin MListAlgo!(SList, getThis);

  /** Get a ReadOnly view of the container */
  .SList!(Value, true, Alloc) readonly() {
    .SList!(Value, true, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .SList!(Value, false, Alloc) readwrite() {
    .SList!(Value, false, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  static if (!ReadOnly) {

  /** Appends an item to the tail of the list.  If the target list is
   *  a sub-list call addAfter instead of addTail to insert an item
   *  after a sub-list.
   */
  void addTail(Value v) {
    if (tail_ is null) {
      // no available nodes so allocate a new one
      tail_ = newNode();
    } else {
      tail_ = tail_.next;
    }
    tail_.data = v; 
    if (head_ is null)
      head_ = tail_;
  }

  /** Appends a list to the tail of the target list.  If the target
   * list is a sub-list call addAfter instead of addTail to insert
   * another list after a sub-list.
   */
  void addTail(SList v) {
    if (v.head_ is null)
      return;
    tail_.next = v.head_;
    tail_ = v.tail_;
    if (head_ is null)
      head_ = v.head_;
  }

  mixin MListCatOperators!(SList);

  /** Prepends an item to the head of the target list.    */
  void addHead(Value v) {
    if (head_ is null) {
      addTail(v);
    } else if (tail_.next is null) {
      // no available nodes so allocate a new one
      Node* t = head_;
      head_ =  new Node();
      head_.data = v;
      head_.next = t;
    } else {
      // grab available node from end
      Node* t = tail_.next;
      tail_.next = t.next;
      t.next = head_;
      head_ = t;
      t.data = v; 
    }
  }

  /** Prepends a list to the head of the target list.   */
  void addHead(SList v) {
    if (v.head_ is null)
      return;
    Node* t = head_;
    head_ = v.head_;
    v.tail_.next = t;
    if (tail_ is null)
      tail_ = v.tail_;
  }

  /** Removes and returns the head item of the list. The node that
   * contained the item may be reused in future additions to the
   * list. To prevent the node from being reused call <tt>trim</tt>.
   * If the target list is empty an IndexOutOfBoundsException is thrown
   * unless version=MinTLNoIndexChecking is set.
   */
  Value takeHead() {
    boundsCheck(head_);
    Node* v = head_;
    head_ = v.next;
    // save node for future reuse
    v.next = tail_.next;
    tail_.next = v;
    Value data = v.data;
    v.data = Value.init;
    return data;
  }

  /** Removes the head item of the list.   */
  void removeHead() {
    boundsCheck(head_);
    Node* v = head_;
    head_ = v.next;
    // save node for future reuse
    v.next = tail_.next;
    tail_.next = v;
    v.data = Value.init;
  }
  
  /** Insert a list after a sub-list.   */
  void addAfter(SList subv, SList v) {
    if (v.tail_ is null)
      return;
    Node* t = subv.tail_;
    if (t is null) {
      *this = v;
      return;
    }
    v.tail_.next = t.next;
    t.next = v.head_;
    if (t is tail_)
      tail_ = v.tail_;
  }

  /** Trims off extra nodes that are not actively being used by the
   * list but are available for recyling for future add operations.
   */
  void trim() {
    if (tail_ !is null)
      tail_.next = null;
  }

  /** Removes n items after a sublist.   */
  void removeAfter(SList sublist, size_t n = 1) {
    if (sublist.head_ is null)
      return;
    boundsCheck(head_);
    Node* t = sublist.tail_;
    Node* newt = t.next;
    while (n--)
      newt = newt.next;
    t.next = newt;
    if (newt is tail_)
      tail_ = t;
  }

  /** Removes items between the tail of a to the head to b (exclusive).   */
  void removeBetween(SList a, SList b) {
    // what to do if a or b is null?
    boundsCheck(head_);
    a.tail_.next = b.head_;
  }

  /** Set the value of one-item slice (more generally the head value). */
  void value(Value newValue) {
    head_.data = newValue;
  }

  } // !ReadOnly

  /** Move a sub-list towards the tail by n items. By default moves
   * to the next item.
   */
  void next(int n = 1, int end = 0) {
    while (n-- > 0) {
      if (end <= 0)
	head_ = head_.next;
      if (end >= 0)
	tail_ = tail_.next;
    }
  }

  /** Duplicates a list.  */
  .SList!(Value,ReadOnly,Alloc) dup() {
    .SList!(Value,false,Alloc) res;
    foreach(ValueType val; *this) {
      res ~= val;
    }
    static if (ReadOnly) {
      return res.readonly;
    } else {
      return res;
    }
  }

  /** Get the value of one-item slice (more generally the head value). 
   * Useful for expressions like x.tail.value or x.head.value. */
  Value value() {
    return head_.data;
  }

  alias opApplyNoKey opApply;
  alias opApplyWithKey opApply;
  alias opApplyIter opApply;

  private Node* newNode() {
    static if (is(Alloc == GCAllocator)) {
      // allocate a block of nodes and return pointer to first one
      Node[] block = new Node[NodeAllocationBlockSize];
      for (int k=1; k<NodeAllocationBlockSize; k++) {
	block[k-1].next = &block[k];
      }
      return &block[0];
    } else {
      // can only allocate one at a time because we have to track each
      Node* p = cast(Node*)Alloc.gcMalloc(Node.sizeof);
      *p = Node.init;
      return p;
    }
  }

  invariant {
    assert( (head_ is null && tail_ is null) ||
	    (head_ !is null && tail_ !is null) );
  }

}

/** \class CircularSList
 * \brief A circular singly-linked list.
 *
 * A CircularSList!(Value) is a circular singly linked list of data of type
 * Value.  A CircularSList differs from an SList in that the tail of the list
 * is linked to the head. As a consequence no nodes are saved and
 * reused between <tt>add</tt> and <rr>remove</tt> functions and
 * slices can be moved forward around the list indefinitely. A CircularSList
 * also has a smaller memory footprint since it requires only one
 * pointer for the tail instead of two pointers for a tail and head.
 *
 * The optional ReadOnly parameter CircularSList!(Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter CircularSList!(Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct CircularSList(Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias CircularSList       ContainerType;
  alias SList!(Value,ReadOnly,Alloc) SliceType;
  alias Value               ValueType;
  alias size_t              IndexType;
  alias SNode!(Value)       Node; 
  alias ReadOnly            isReadOnly;

  private {
    Node* tail_;  // tail_ is last item
  }

  /** Return the circular list as a non-circular SList.   */
  SliceType toSList() {
    SliceType res;
    if (tail_ is null)
      return res;
    res.head_ = tail_.next;
    res.tail_ = tail_;
    return res;
  }

  /** Get a ReadOnly view of the container */
  .CircularSList!(Value, true, Alloc) readonly() {
    .CircularSList!(Value, true, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .CircularSList!(Value, false, Alloc) readwrite() {
    .CircularSList!(Value, false, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  static if (!ReadOnly) {

  /** Appends an item to the tail of the list.  If the target list is
   *  a sub-list call addAfter instead of addTail to insert an item
   *  after a sub-list.
   */
  void addTail(Value v) {
    Node* n = new Node;
    n.data = v;
    addNode(n);
    tail_ = n;
  }

  /** Adds a node after tail.   */
  private void addNode(Node* n) {
    if (tail_ is null) {
      n.next = n;
      tail_ = n;
    } else {
      n.next = tail_.next;
      tail_.next = n;
    }
  }

  /** Appends a list to the tail of the target list.  If the target
   * list is a sub-list call addAfter instead of addTail to insert
   * another list after a sub-list.
   */
  void addTail(CircularSList v) {
    addHead(v);
    tail_ = v.tail_;
  }

  mixin MListCatOperators!(CircularSList);

  /** Appends an item to the tail of the list.  If the target list is
   *  a sub-list call addAfter instead of addTail to insert an item
   *  after a sub-list.
   */
  void addHead(Value v) {
    Node* n = newNode();
    n.data = v;
    addNode(n);
  }

  /** Appends a list to the tail of the target list.  If the target
   * list is a sub-list call addAfter instead of addTail to insert
   * another list after a sub-list.
   */
  void addHead(CircularSList v) {
    if (v.tail_ is null)
      return;
    if (tail_ is null) {
      tail_ = v.tail_;
      return;
    }
    v.tail_.next = tail_.next;
    tail_.next = v.tail_;
  }

  /** Removes and returns the head item of the list.    */
  Value takeHead() {
    boundsCheck(tail_);
    Node* v = tail_.next;
    tail_.next = v.next;
    Value val = v.data;
    freeNode(v);
    return val;
  }

  /** Removes the head item of the list.   */
  void removeHead() {
    boundsCheck(tail_);
    Node* v = tail_.next;
    tail_.next = v.next;
    freeNode(v);
  }

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      Node* i = head_;
      if (i !is null) 
	tail_.next = null;
      while (i !is null) {
	Node* next = i.next;
	Alloc.gcFree(i);
	i = next;
      }
    }
    *this = CircularSList.init;
  }

  /** Insert a list after a sub-list.   */
  void addAfter(SliceType subv, SliceType v) {
    if (v.tail_ is null)
      return;
    Node* t = subv.tail_;
    if (t is null) {
      tail_ = v.tail_;
      return;
    }
    v.tail_.next = t.next;
    t.next = v.head_;
    if (t is tail_)
      tail_ = v.tail_;
  }

  /** Removes n items after a sublist.   */
  void removeAfter(SliceType sublist, size_t n = 1) {
    if (sublist.head_ is null)
      return;
    boundsCheck(tail_);
    Node* t = sublist.tail_;
    Node* newt = t.next;
    while (n--) {
      Node* i = newt;
      newt = newt.next;
      freeNode(i);
    }
    t.next = newt;
    if (newt is tail_)
      tail_ = t;
  }

  /** Removes items between the tail of a to the head to b (exclusive). 
   * If a custom allocator is used the memory is not freed automatically.
   */
  void removeBetween(SliceType a, SliceType b) {
    // what to do if a or b is null?
    boundsCheck(tail_);
    a.tail_.next = b.head_;
  }

  } // !ReadOnly

  /** Duplicates a list.  */
  .CircularSList!(Value,ReadOnly,Alloc) dup() {
    .CircularSList!(Value,false,Alloc) res;
    foreach(ValueType val; *this) {
      res ~= val;
    }
    static if (ReadOnly) {
      return res.readonly;
    } else {
      return res;
    }
  }

  /** Rotate the list.   */
  void rotate(int n = 1) {
    while (n-- > 0)
      tail_ = tail_.next;
  }

  private Node* head_() {
    if (tail_ is null) return null;
    return tail_.next;
  }

  CircularSList getThis(){return *this;}
  mixin MListAlgo!(CircularSList, getThis);

  mixin MCommonSList!(head_, CircularSList );

  alias opApplyNoKey opApply;
  alias opApplyWithKey opApply;
  alias opApplyIter opApply;

  private Node* newNode() {
    static if (is(Alloc == GCAllocator)) {
      return new Node;
    } else {
      Node* p = cast(Node*)Alloc.gcMalloc(Node.sizeof);
      *p = Node.init;
      return p;
    }
  }

  private void freeNode(Node* n) {
    static if (is(Alloc == GCAllocator)) {
    } else {
      Alloc.gcFree(n);
    }
  }
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;

version (MinTLUnittest) {
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.slist unittest\n");
    SList!(int) x;
    x.add(3,4);
    assert( x[0] == 3 );
    assert( x[1] == 4 );
    assert( x.length == 2 );

    // test addHead
    SList!(int) y;
    y.addHead(4);
    y.addHead(3);

    // test ==
    assert( x == y );
    SList!(int) w = x.dup;
    w ~= 5;
    assert( x != w);

    // test remove
    assert( w.takeHead() == 3 );
    w.trim();
    w.addHead(3);

    SList!(int) z = x.dup;
    // test foreach iteration
    foreach(size_t n, inout int val; z) {
      val = n*10;
    }
    assert( z[0] == 0 );
    assert( z[1] == 10 );
    int n = 0;
    foreach(SList!(int) itr; z) {
      assert(itr[0] == z[n++]);
    }

    // test slicing
    SList!(int) v = w[1..3];
    assert( v.length == 2 );
    assert( v[0] == 4 );
    assert( v[1] == 5 );
  
    // test algorithms
    assert( v.opIn(5) == v.tail );
    assert( v.count(5) == 1 );

    // test another node type
    SList!(char[]) str;
    str ~= "hello";
    str ~= "world";
    assert( str[str.length-1] == "world" );

    // test sub-list spanning
    SList!(int) tmp;
    int[10] tmp2;
    tmp2[3] = 100;
    tmp2[8] = 200;
    foreach(int xx;tmp2)
      tmp ~= xx;
    SList!(int) a,b,c;
    a = tmp[3..5];
    b = tmp[7..9];
    c = tmp[a..b];
    assert( c.length == 6 );
    assert( c[0] == 100 );
    assert( c[5] == 200 );

    // CircularSList

    CircularSList!(int) cx;
    cx.add(3,4);
    assert( cx[0] == 3 );
    assert( cx[1] == 4 );
    assert( cx.length == 2 );

    // test addHead
    CircularSList!(int) cy;
    cy.addHead(4);
    cy.addHead(3);

    // test ==
    assert( cx == cy );
    CircularSList!(int) cw = cx.dup;
    cw ~= 5;
    assert( cx != cw);

    // test remove
    assert( cw.takeHead() == 3 );
    cw.addHead(3);

    CircularSList!(int) cz = cx.dup;
    // test foreach iteration
    foreach(size_t n, inout int val; cz) {
      val = n*10;
    }
    assert( cz[0] == 0 );
    assert( cz[1] == 10 );
    n = 0;
    foreach(SList!(int) itr; cz) {
      assert(itr[0] == cz[n++]);
    }

    // test slicing
    SList!(int) cv = cw[1..3];
    assert( cv.length == 2 );
    assert( cv[0] == 4 );
    assert( cv[1] == 5 );
  
    // test algorithms
    assert( cv.opIn(5) == cv.tail );
    assert( cv.count(5) == 1 );

    // test another node type
    CircularSList!(char[]) cstr;
    cstr ~= "hello";
    cstr ~= "world";
    assert( cstr[cstr.length-1] == "world" );

    // test sub-list spanning
    CircularSList!(int) ctmp;
    int[10] ctmp2;
    ctmp2[3] = 100;
    ctmp2[8] = 200;
    foreach(int xx; ctmp2)
      ctmp ~= xx;
    SList!(int) ca,cb,cc;
    ca = ctmp[3..5];
    cb = ctmp[7..9];
    cc = ctmp[a..b];
    assert( cc.length == 6 );
    assert( cc[0] == 100 );
    assert( cc[5] == 200 );

    version (MinTLVerboseUnittest) 
      printf("finished mintl.slist unittest\n");
  }
}

