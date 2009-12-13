/** \file list.d
 * \brief A doubly-linked list and a circular doubly-linked list.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.7.1
 */

module mintl.list;

private import mintl.share; // for ~ and ~=
private import mintl.sorting;
import mintl.mem;

// shared data structure between List and CircularList
private struct DNode(Value) {
  DNode* next, prev;
  Value data;
  Value* sortLookup(){return &data;}
}

/** Template for member functions common to List and CircularList  */
template MCommonList(alias tail_, Container ) {

  /** Test if a container is empty. */
  bool isEmpty() { 
    return head_ is null;
  }

  /** Get the length of list. The computation can be O(n) but the
   * result is cached and the actively updated until another list
   * of unknown length is concatenated or removed.
   */
  size_t length() {
    if (length_ == 0 && head_) {
      Container.Node* n = head_;
      length_ = 1;
      Container.Node* end = tail_;
      while (n !is end) {
	length_++;
	n = n.next;
      }
    }
    return length_;
  }

  // helper function to check if the index is legal
  void boundsCheck(size_t n) {
    version (MinTLNoIndexChecking) {
    } else {
      if (!(n == 0 && this.head_) &&
	  (n >= length_ && n >= this.length)) {
	throw new IndexOutOfBoundsException();
      }
    }
  }

  // Internal function to get the nth item of the list.
  package Container.Node* getNode(size_t n) {
    boundsCheck(n);
    Container.Node* v;
    if (n <= length_/2) {
      v = head_;
      while (n--) {
	v = v.next;
      }
    } else {
      n = length_-n-1;
      v = tail_;
      while (n--) {
	v = v.prev;
      }
    }
    return v;
  }

  /** Get the nth item in the list from head. The operation is O(N(n))
   * where N(x) is the distance from x to either end of list.
   * Indexing out of bounds throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  Container.ValueType opIndex(size_t n) {
    return getNode(n).data;
  }

  static if (!Container.isReadOnly) {

  /** Get a pointer to the nth item in the list from head. The
   * operation is O(N(n)) where N(x) is the distance from x to either
   * end of list.  Indexing out of bounds throws an
   * IndexOutOfBoundsException unless version=MinTLNoIndexChecking is
   * set.
   */
  Container.ValueType* lookup(size_t n) {
    return &getNode(n).data;
  }

  /** Set the nth item in the list from head. The operation is O(N(n))
   * where N(x) is the distance from x to either end of list.
   * Indexing out of bounds throws an IndexOutOfBoundsException unless
   * version=MinTLNoIndexChecking is set.
   */
  void opIndexAssign(Container.ValueType val, size_t n) {
    getNode(n).data = val;
  }

  /** Reverse a list in-place.  The operation is O(n) where n is
   * length of the list.
   */
  Container reverse() {
    if (this.isEmpty)
      return *this;
    Node* i = head_;
    Node* j = tail_;
    TypeInfo ti = typeid(Container.ValueType);
    while (i !is j && i.next !is j) {
      ti.swap(&i.data,&j.data);
      i = i.next;
      j = j.prev;
    } 
    ti.swap(&i.data,&j.data);
    return *this;
  }

  } // !isReadOnly

  /** Copies the list contents to an array   */
  Container.ValueType[] values() {
    Container.ValueType[] buffer = new Container.ValueType[this.length];
    foreach(size_t n, Container.ValueType val; *this) {
      buffer[n] = val;
    }
    return buffer;
  }

  /** Test for equality of two lists.  The operation is O(n) where n
   * is length of the list.
   */
  int opEquals(Container c) {
    if (length_ && c.length_ && length_ != c.length_)
      return 0;
    Container.Node* i = head_;
    Container.Node* j = c.head_;
    Container.Node* t = tail_;
    Container.Node* ct = c.tail_;
    TypeInfo ti = typeid(Container.ValueType);
    while (i !is null && j !is null) {
      if (!ti.equals(&i.data,&j.data))
	return 0;
      if (i !is t && j !is ct) 
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
      if (i !is t && j !is ct) 
	return 0;
      i = i.next;
      j = j.next;
    } 
    if (i is null && j is null)
      return 0;
    else 
      return (i is null) ? -1 : 1;
  }

  /** Create a sub-list from index a to b (exclusive). The operation is
   * O(max(N(a),N(b))) where N(x) is distance from x to either end of 
   * the target list.
   */
  Container.SliceType opSlice(size_t a, size_t b) {
    Container.SliceType res;
    res.length_ = b-a;
    if (res.length_ > 0) {
      res.head_ = getNode(a);
      if (this.length_ - b > b-a){
	Container.Node* v = res.head_;
	b = b-a-1;
	while (b--)
	  v = v.next;
	res.tail_ = v;
      } else {
	res.tail_ = getNode(b-1);
      }
    }
    return res;
  }

  /** Create a sub-list from the head of a to the tail of b (inclusive).  */
  Container.SliceType opSlice(Container.SliceType a, Container.SliceType b) {
    if (a.isEmpty)
      return b;
    if (b.isEmpty)
      return a;
    Container.SliceType res;
    Container.Node* i = a.head_;
    res.head_ = i;
    res.tail_ = b.tail_;
    res.length_ = 0; // flag indicating unknown length
    return res;
  }

  /** Iterates over the list from head to tail calling delegate to
   * perform an action. The value is passed to the delegate.
   */
  int opApplyNoKeyStep(int delegate(inout Container.ValueType x) dg, int step = 1){
    int dg2(inout size_t count, inout Container.ValueType val) {
      return dg(val);
    }
    return opApplyWithKeyStep(&dg2,step);
  }
  
  /** Iterates over the list from head to tail calling delegate to
   * perform an action. The index from 0 and the value are passed
   * to the delegate.
   */
  int opApplyWithKeyStep(int delegate(inout size_t n, inout Container.ValueType x) dg,
			 int step = 1){
    Container.Node* i = step>0 ? head_ : tail_;
    Container.Node* end = step>0 ? tail_ : head_;
    int res = 0;
    size_t n = step>0 ? 0 : this.length-1;
    while (i !is null) {
      res = dg(n, i.data);
      if (res || i is end) break;
      n += step;
      i = step>0 ? i.next : i.prev;
    } 
    return res;
  }

  /** Iterates over the list from head to tail calling delegate to
   * perform an action. A one-item sub-list is passed to the delegate.
   */
  int opApplyIterStep(int delegate(inout Container.SliceType n) dg, int step = 1){
    Container.Node* i = step>0 ? head_ : tail_;
    Container.Node* end = step>0 ? tail_ : head_;
    int res = 0;
    Container.SliceType n;
    n.length_ = 1;
    while (i !is null) {
      n.head_ = n.tail_ = i;
      res = dg(n);
      if (res || i is end) break;
      i = step>0 ? i.next : i.prev;
    } 
    return res;
  }

}

/** \class List
 * \brief A doubly-linked list.
 *
 * A List!(Value) is a linked list of data of type Value. A list is
 * similar to a dynamic array except accessing an element in the
 * middle of the list is O(n) and appending to the front or back is
 * O(1). Any operation that is not constant-time will explicitly have
 * the performance behavior documented.
 *
 * The optional ReadOnly parameter List!(Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter List!(Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct List(Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias List   ContainerType;
  alias List   SliceType;
  alias Value  ValueType;
  alias size_t IndexType;
  alias Value  SortType;
  alias DNode!(Value) Node;
  alias ReadOnly isReadOnly;

  const int NodeAllocationBlockSize = 10; // allocate 10 nodes at a time

  /* length 0 means length is unknown. An empty list is indicated by
   * a null head. The tail can be non-null in order to maintain the
   * cached nodes.
   */
  invariant {
    assert( length_ == 0 || head_ !is null );
  }

  // private bug  private {
    size_t length_;
    Node* head_;
    Node* tail_;
    //  }

  /** Get a ReadOnly view of the container */
  .List!(Value, true, Alloc) readonly() {
    .List!(Value, true, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .List!(Value, false, Alloc) readwrite() {
    .List!(Value, false, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  static if (!ReadOnly) {

  /** Appends an item to the tail of the list.  If the target list is
   *  a sub-list call addAfter instead of addTail to insert an item
   *  after a sub-list.
   */
  void addTail(Value v) {
    if (head_ is null && tail_ !is null) {
      // empty list but with cache available
      head_ = tail_;
      tail_.data = v; 
      length_ = 1;
    } else if (tail_ is null || tail_.next is null) {
      if (head_ is null || head_.prev is null) {
	// no available nodes so allocate a new one
	List val;
	val.head_ = val.tail_ = newNode();
	val.length_ = 1;
	val.head_.data = v;
	addTail(val);
      } else {
	// grab available node from front
	Node* t = head_.prev;
	if (t.prev !is null) t.prev.next = head_;
	head_.prev = t.prev;
	t.prev = tail_;
	t.next = null;
	tail_.next = t;
	tail_ = t;
	tail_.data = v; 
	if (length_) length_++;
      }
    } else {
      // grab available node from end
      tail_.next.prev = tail_;
      tail_ = tail_.next;
      tail_.data = v; 
      if (length_) length_++;
    }
  }

  /** Appends a list to the tail of the target list.  If the target
   * list is a sub-list call addAfter instead of addTail to insert
   * another list after a sub-list.
   */
  void addTail(List v) {
    if (v.isEmpty)
      return;
    if (tail_ !is null)
      tail_.next = v.head_;
    v.head_.prev = tail_;
    if (this.isEmpty)
      length_ = v.length_;
    else
      length_ = increaseLength(length_, v.length_);
    tail_ = v.tail_;
    if (head_ is null)
      head_ = v.head_;
  }

  mixin MListCatOperators!(List);

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      trim();
      Node* i = head_;
      while (i !is null) {
	Node* next = i.next;
	Alloc.gcFree(i);
	i = next;
      }
    }
    *this = List.init;
  }

  /** Set the value of one-item slice (more generally the head value). */
  void value(Value newValue) {
    head_.data = newValue;
  }

  // Helper function for take and remove
  private Node* takeTailHelper() {
    if (this.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* v = tail_;
    if (head_ && head_ is tail_) {
      head_ = null;
    } else {
      tail_ = tail_.prev;
    }
    return v;
  }

  /** Removes and returns the tail item of the list. The node that
   * contained the item may be reused in future additions to the
   * list. To prevent the node from being reused call <tt>trim</tt> or
   * call <tt>remove</tt> with a sublist containing the last item. If
   * the target list is empty an IndexOutOfBoundsException is thrown
   * unless version=MinTLNoIndexChecking is set.
   */
  Value takeTail() {
    Node* v = takeTailHelper();
    Value data = v.data;
    v.data = Value.init;
    if (length_) length_--;
    return data;
  }

  /** Removes the tail item of the list.   */
  void removeTail() {
    Node* v = takeTailHelper();
    v.data = Value.init;
    if (length_) length_--;
  }

  /** Prepends an item to the head of the target list.  If the target
   * list is a sub-list call addBefore instead of addHead to insert an
   * item before a sub-list.
   */
  void addHead(Value v) {
    if (head_ is null && tail_ !is null) {
      // empty list but with cache available
      head_ = tail_;
      tail_.data = v; 
      length_ = 1;
    } else if (head_ is null || head_.prev is null) {
      if (tail_ is null || tail_.next is null) {
	// no available nodes so allocate a new one
	List val;
	val.head_ = val.tail_ = newNode();
	val.length_ = 1;
	val.head_.data = v;
	addHead(val);
      } else {
	// grab available node from end
	Node* t = tail_.next;
	if (t.next !is null) t.next.prev = tail_;
	tail_.next = t.next;
	t.next = head_;
	t.prev = null;
	head_.prev = t;
	head_ = t;
	head_.data = v; 
	if (length_) length_++;
      }
    } else {
      // grab available node from front
      head_.prev.next = head_;
      head_ = head_.prev;
      head_.data = v; 
      if (length_) length_++;
    }
  }

  /** Prepends a list to the head of the target list.  If the target
   *  list is a sub-list call addBefore instead of addHead to insert a
   *  list before a sub-list.
   */
  void addHead(List v) {
    if (v.isEmpty)
      return;
    if (head_ !is null)
      head_.prev = v.tail_;
    v.tail_.next = head_;
    if (this.isEmpty)
      length_ = v.length_;
    else
      length_ = increaseLength(length_, v.length_);
    head_ = v.head_;
    if (tail_ is null)
      tail_ = v.tail_;
  }

  // Helper function for take and remove
  private Node* takeHeadHelper() {
    if (this.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* v = head_;
    if (head_ && head_ is tail_) {
      head_ = null;
    } else {
      head_ = head_.next;
    }
    return v;
  }

  /** Removes and returns the head item of the list. The node that
   * contained the item may be reused in future additions to the
   * list. If the target list is empty an IndexOutOfBoundsException is
   * thrown unless version=MinTLNoIndexChecking is set.
   */
  Value takeHead() {
    Node* v = takeHeadHelper();
    Value data = v.data;
    v.data = Value.init;
    if (length_) length_--;
    return data;
  }
  
  /** Removes the head item of the list.   */
  void removeHead() {
    Node* v = takeHeadHelper();
    v.data = Value.init;
    if (length_) length_--;
  }
  
  /** Insert a list before a sub-list.   */
  void addBefore(List subv, List v) {
    if (v.isEmpty)
      return;
    if (subv.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* t = subv.head_;
    if (t.prev !is null) {
      t.prev.next = v.head_;
    }
    v.head_.prev = t.prev;
    v.tail_.next = t;
    t.prev = v.tail_;
    if (t is head_)
      head_ = v.head_;
    length_ = increaseLength(length_, v.length_);
  }

  /** Insert a list after a sub-list.   */
  void addAfter(List subv, List v) {
    if (v.isEmpty)
      return;
    if (subv.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* t = subv.tail_;
    if (t.next !is null) {
      t.next.prev = v.tail_;
    }
    v.tail_.next = t.next;
    v.head_.prev = t;
    t.next = v.head_;
    if (t is tail_)
      tail_ = v.tail_;
    length_ = increaseLength(length_, v.length_);
  }


  /** Removes a sub-list from the list entirely.   */
  void remove(List sublist) {
    if (sublist.isEmpty)
      return;
    Node* h = sublist.head_;
    Node* t = sublist.tail_;
    if (h is head_ && t is tail_) {
      head_ = tail_ = null;
      length_ = 0;
      return;
    } 
    Node* hp = h.prev;
    Node* tn = t.next;
    if (hp !is null)
      hp.next = tn;
    if (tn !is null)
      tn.prev = hp;
    if (h is head_)
      head_ = tn;
    if (t is tail_)
      tail_ = hp;
    length_ = decreaseLength(length_, sublist.length_);
  }

  /** Removes an item from the list if present.   */
  void remove(size_t index) {
    List item = opSlice(index, index+1);
    remove(item);
  }

  /** Removes an item and return the value if any.   */
  Value take(size_t index) {
    List item = opSlice(index, index+1);
    remove(item);
    Value val = item[0];
    item.clear();
    return val;
  }

  /** Trims off extra nodes that are not actively being used by the
   * list but are available for recyling for future add operations.
   * This function should be called after calling <tt>remove</tt> and
   * there are other list or pointer references to the removed item.
   */
  void trim() {
    if (!this.isEmpty) {
      Node* i;
      if (tail_.next) {
	i = tail_.next;
	i.prev = null;
	tail_.next = null;
	static if (is(Alloc == GCAllocator)) {
	} else {
	  while (i !is null) {
	    Node* next = i.next;
	    Alloc.gcFree(i);
	    i = next;
	  }
	}
      }
      if (head_.prev) {
	i = head_.prev;
	i.next = null;
	head_.prev = null;
	static if (is(Alloc == GCAllocator)) {
	} else {
	  while (i !is null) {
	    Node* prev = i.prev;
	    Alloc.gcFree(i);
	    i = prev;
	  }
	}
      }
    }
  }

  } // !ReadOnly

  /** Duplicates a list. The operation is O(n) where n is length of
   * the list.
   */
  List dup() {
    .List!(Value,false,Alloc) res;
    foreach(ValueType val; *this) {
      res ~= val;
    }
    static if (ReadOnly) {
      return res.readonly;
    } else {
      return res;
    }
  }

  /** Move a sub-list towards the head or tail by n items. If n is 
   * negative the sub-list moves towards the head. A positive end is
   * the tail, negative the head and 0 is both. By default moves to
   * the next item.
   */
  void next(int n = 1, int end = 0) {
    if (length_) 
      length_ -= n*end;
    while (n-- > 0) {
      if (end <= 0)
	head_ = head_.next;
      if (end >= 0)
	tail_ = tail_.next;
    }
    while (++n < 0) {
      if (end <= 0)
	head_ = head_.prev;
      if (end >= 0)
	tail_ = tail_.prev;
    }
  }

  /** Get the length of list. The computation can be O(n) but the
   * result is cached and the actively updated until another list
   * of unknown length is concatenated.
   */
  size_t length() {
    if (length_ == 0 && !this.isEmpty) {
      Node* n = head_;
      length_ = 1;
      while (n !is tail_) {
	length_++;
	n = n.next;
      }
    }
    return length_;
  }

  /** Create a one-item slice of the head.  */
  List head() {
    List res;
    res.length_ = head_? 1 : 0;
    res.head_ = res.tail_ = head_;
    return res;
  }

  /** Create a one-item slice of the tail.   */
  List tail() {
    List res;
    res.length_ = tail_? 1 : 0;
    res.head_ = res.tail_ = tail_;
    return res;
  }

  /** Get the value of one-item slice (more generally the head value). 
   * Useful for expressions like x.tail.value or x.head.value. */
  Value value() {
    return head_.data;
  }

  /** Iterate backwards over the list (from tail to head).  This
   *  should be called as the iteration parameter in a
   *  <tt>foreach</tt> statement
   */
  ListReverseIter!(Value,ReadOnly,Alloc) backwards() {
    ListReverseIter!(Value,ReadOnly,Alloc) res;
    res.list = this;
    return res;
  }

  /**  Helper functions for opApply   */
  mixin MOpApplyImpl!(ContainerType);
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

  List getThis(){return *this;}
  mixin MListAlgo!(List, getThis);
  Node* getHead(){return head_;}
  Node* getTail(){return tail_;}
  mixin MSequentialSort!(List, getHead,getTail);
  void sort(int delegate(Value*a, Value*b) cmp = null) {
    Node* newhead, newtail;
    dosort(newhead,newtail,cmp);
    head_ = newhead;
    tail_ = newtail;
  }
  mixin MCommonList!(tail_, List );
  void privateMake(Node* h, Node* t, size_t len) {
    head_ = h;
    tail_ = t;
    length_ = len;
  }
}

// helper structure for backwards()
struct ListReverseIter(Value,bit ReadOnly,Alloc) {
  mixin MReverseImpl!(List!(Value,ReadOnly,Alloc));
}

/** \class CircularList
 * \brief A circular doubly-linked list.
 *
 * A CircularList!(Value) is a circular doubly linked list of data of type
 * Value.  A CircularList differs from a List in that the tail of the list
 * is linked to the head. As a consequence no nodes are saved and
 * reused between <tt>add</tt> and <rr>remove</tt> functions and
 * slices can be moved forward around the list indefinitely. A CircularList
 * also has a smaller memory footprint since it requires only one
 * pointer for the head instead of two pointers for a tail and head.
 *
 * The optional ReadOnly parameter CircularList!(Value,ReadOnly) forbids
 * operations that modify the container. The readonly() property returns
 * a ReadOnly view of the container.
 *
 * The optional allocator parameter CircularList!(Value,false,Allocator) is used
 * to allocate and free memory. The GC is the default allocator.
 */
struct CircularList(Value, bit ReadOnly = false, Alloc = GCAllocator) {

  alias CircularList       ContainerType;
  alias List!(Value,ReadOnly,Alloc) SliceType;
  alias Value              ValueType;
  alias size_t             IndexType;
  alias DNode!(Value)      Node;
  alias ReadOnly isReadOnly;

  private {
    size_t length_;
    Node* head_;
  }

  /* length 0 means length is unknown. */
  invariant {
    assert( length_ == 0 || head_ !is null );
  }

  /** Return the circular list as a non-circular List.
   * \return the list as a List
   */
  SliceType toList() {
    SliceType res;
    if (this.isEmpty)
      return res;
    res.privateMake(head_,head_.prev,length_);
    //    res.tail_ = 
    //    res.head_ = head_;
    //    res.length_ = length_;
    return res;
  }

  /** Get a ReadOnly view of the container */
  .CircularList!(Value, true, Alloc) readonly() {
    .CircularList!(Value, true, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  /** Get a read-write view of the container */
  .CircularList!(Value, false, Alloc) readwrite() {
    .CircularList!(Value, false, Alloc) res;
    res = *cast(typeof(&res))this;
    return res;
  }

  private Node* tail_() {
    if (this.isEmpty) return null;
    return head_.prev;
  }

  static if (!ReadOnly) {

  /** Rotate the list by n items. If n is negative the rotation is 
   * reversed.
   */
  void rotate(int n = 1) {
    if (n >= 0) {
      while (n-- > 0)
	head_ = head_.next;
    } else {
      while (++n < 0)
	head_ = head_.prev;
    }
  }

  /** Clear all contents. */
  void clear() {
    static if (is(Alloc == GCAllocator)) {
    } else {
      Node* i = head_;
      if (i !is null) 
	i.prev.next = null;
      while (i !is null) {
	Node* next = i.next;
	Alloc.gcFree(i);
	i = next;
      }
    }
    *this = CircularList.init;
  }
  /** Appends an item to the tail of the list.  If the target list is
   *  a sub-list call addAfter instead of addTail to insert an item
   *  after a sub-list.
   */
  void addTail(Value v) {
    Node* n = newNode();
    n.data = v;
    addNode(n);
  }

  private void link(Node* a, Node* b) {
    a.next = b;
    b.prev = a;
  }

  /** Adds a node before head.   */
  private void addNode(Node* n) {
    if (this.isEmpty) {
      link(n,n);
      head_ = n;
      length_ = 1;
    } else {
      link(tail_,n);
      link(n,head_);
      if (length_) length_++;
    }
  }

  /** Appends a list to the tail of the target list.  If the target
   * list is a sub-list call addAfter instead of addTail to insert
   * another list after a sub-list.
   */
  void addTail(CircularList v) {
    addHead(v);
  }

  mixin MListCatOperators!(CircularList);

  // Helper function for take and remove
  private Node* takeTailHelper() {
    if (this.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* v = tail_;
    if (head_ && head_ is tail_) {
      head_ = null;
    } else {
      link(v.prev,v.next);
    }
    return v;
  }

  /** Removes and returns the tail item of the list. The node that
   * contained the item may be reused in future additions to the
   * list. To prevent the node from being reused call <tt>trim</tt> or
   * call <tt>remove</tt> with a sublist containing the last item. If
   * the target list is empty an IndexOutOfBoundsException is thrown
   * unless version=MinTLNoIndexChecking is set.
   */
  Value takeTail() {
    Node* v = takeTailHelper();
    Value data = v.data;
    freeNode(v);
    if (length_) length_--;
    return data;
  }

  /** Removes the tail item of the list.   */
  void removeTail() {
    Node* v = takeTailHelper();
    if (length_) length_--;
    freeNode(v);
  }

  /** Prepends an item to the head of the target list.  If the target
   * list is a sub-list call addBefore instead of addHead to insert an
   * item before a sub-list.
   */
  void addHead(Value v) {
    Node* n = new Node;
    n.data = v;
    addNode(n);
    head_ = n;
  }

  /** Prepends a list to the head of the target list.  If the target
   *  list is a sub-list call addBefore instead of addHead to insert a
   *  list before a sub-list.
   */
  void addHead(CircularList v) {
    if (v.isEmpty)
      return;
    if (this.isEmpty) {
      *this = v;
      return;
    }
    Node* vt = v.tail_;
    link(tail_,v.head_);
    link(vt,head_);
    head_ = v.head_;
    length_ = increaseLength(length_, v.length_);
  }

  // Helper function for take and remove
  private Node* takeHeadHelper() {
    if (this.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* v = head_;
    if (head_ && head_ is tail_) {
      head_ = null;
    } else {
      link(v.prev,v.next);
    }
    return v;
  }

  /** Removes and returns the head item of the list. The node that
   * contained the item may be reused in future additions to the
   * list. To prevent the node from being reused call <tt>trim</tt> or
   * call <tt>remove</tt> with a sublist containing the last item.  If
   * the target list is empty an IndexOutOfBoundsException is thrown
   * unless version=MinTLNoIndexChecking is set.
   */
  Value takeHead() {
    Node* v = takeHeadHelper();
    Value data = v.data;
    if (length_) length_--;
    freeNode(v);
    return data;
  }

  /** Removes the head item of the list.    */
  void removeHead() {
    Node* v = takeHeadHelper();
    if (length_) length_--;
    freeNode(v);
  }
  
  /** Insert a list before a sub-list.   */
  void addBefore(SliceType subv, SliceType v) {
    if (v.isEmpty)
      return;
    if (subv.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* t = subv.head_;
    link(t.prev,v.head_);
    link(v.tail_,t);
    if (t is head_)
      head_ = v.head_;
    length_ = increaseLength(length_, v.length_);
  }

  /** Insert a list after a sub-list.   */
  void addAfter(SliceType subv, SliceType v) {
    if (v.isEmpty)
      return;
    if (subv.isEmpty)
      throw new IndexOutOfBoundsException();
    Node* t = subv.tail_;
    link(v.tail_,t.next);
    link(t,v.head_);
    length_ = increaseLength(length_, v.length_);
  }


  /** Removes a sub-list from the list entirely.   */
  void remove(SliceType sublist) {
    if (sublist.isEmpty)
      return;
    Node* h = sublist.head_;
    Node* t = sublist.tail_;
    if (h is head_ && t is tail_) {
      head_ = null;
      length_ = 0;
      return;
    } 
    if (h is head_)
      head_ = t.next;
    link(h.prev,t.next);
    h.prev = null;
    t.next = null;
    length_ = decreaseLength(length_, sublist.length_);
  }

  /** Removes an item if present.  */
  void remove(size_t index) {
    remove(opSlice(index, index+1));
  }

  /** Removes an item from the list and return its value, if present.   */
  Value take(size_t index) {
    SliceType item = opSlice(index, index+1);
    remove(item);
    Value val = item[0];
    item.clear();
    return val;
  }

  } // !ReadOnly

  /** Duplicates a list. The operation is O(n) where n is length of
   * the list.
   */
  CircularList dup() {
    .CircularList!(Value,false,Alloc) res;
    foreach(ValueType val; *this) {
      res ~= val;
    }
    static if (ReadOnly) {
      return res.readonly;
    } else {
      return res;
    }
  }

  /** Create a one-item slice of the head.   */
  SliceType head() {
    SliceType res;
    if (this.isEmpty) return res;
    res.head_ = res.tail_ = head_;
    res.length_ = 1;
    return res;
  }

  /** Create a one-item slice of the tail.   */
  SliceType tail() {
    SliceType res;
    if (this.isEmpty) return res;
    res.head_ = res.tail_ = head_.prev;
    res.length_ = 1;
    return res;
  }

  /** Move a sub-list towards the tail by n items.   */
  void next(int n = 1, int end = 0) {
    if (length_) 
      length_ -= n*end;
    while (n-- > 0) {
      if (end <= 0)
	head_ = head_.next;
    }
  }

  /** Iterate backwards over the list (from tail to head).  This
   *  should be called as the iteration parameter in a
   *  <tt>foreach</tt> statement
   */
  CircularListReverseIter!(Value,ReadOnly,Alloc) backwards() {
    CircularListReverseIter!(Value,ReadOnly,Alloc) res;
    res.list = this;
    return res;
  }

  /**
   *  Helper functions for opApply with/without keys and 
   *  forward/backward order
   */
  mixin MOpApplyImpl!(ContainerType);
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

  CircularList getThis(){return *this;}
  mixin MListAlgo!(CircularList, getThis);

  mixin MCommonList!(tail_, CircularList );
}

// helper functions for adjusting length cache
private size_t increaseLength(size_t len, size_t x) {
  return x ? (len? len+x : 0) : 0;
}
private size_t decreaseLength(size_t len, size_t x) {
  return x ? (len? len-x : 0) : 0;
}

// helper structure for backwards()
struct CircularListReverseIter(Value,bit ReadOnly,Alloc) {
  mixin MReverseImpl!(List!(Value,ReadOnly,Alloc),
		      CircularList!(Value,ReadOnly,Alloc));
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;

version (MinTLUnittest) {
  private import std.random;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.list unittest\n");

    List!(int) x;
    x ~= 3;
    x ~= 4;
    assert( x[0] == 3 );
    assert( x[1] == 4 );
    assert( x.length == 2 );
    List!(int) x2 = List!(int).make(3,4);
    assert( x == x2 );

    List!(int) catt;
    catt = List!(int).make(1,2,3) ~ List!(int).make(4,5,6);
    assert( catt == List!(int).make(1,2,3,4,5,6) );

    List!(int,false,MallocNoRoots) xm;
    xm ~= 3;
    xm ~= 4;
    assert( xm[0] == 3 );
    assert( xm[1] == 4 );
    assert( xm.length == 2 );
    xm.clear();
    assert( xm.isEmpty );

    List!(real) x2s;
    x2s.add(cast(real)3,cast(real)4);
    assert( x2s[0] == 3 );
    assert( x2s[1] == 4 );

    // test addHead
    List!(int) y;
    y.addHead(4);
    y.addHead(3);

    // test ==
    assert( x == y );
    List!(int) w = x.dup;
    w ~= 5;
    assert( x != w);

    // test remove/take
    assert( w.takeTail() == 5 );
    size_t wlen = w.length;
    w.addTail(6);
    w.removeTail();
    assert( w.length() == wlen );
    assert( w == x );
    w.trim();
    w ~= 5;

    // test reverse lists
    List!(int) z = y.dup;
    z.reverse();
    assert( z[0] == 4 );
    assert( z[1] == 3 );

    // test foreach iteration
    foreach(size_t n, inout int val; z) {
      val = n*10;
    }
    assert( z[0] == 0 );
    assert( z[1] == 10 );
    foreach(size_t n, int val; y.backwards()) {
      assert(x[n] == val);
    }
    int n = 0;
    foreach(List!(int) itr; y) {
      assert(itr[0] == y[n++]);
    }

    // test slicing
    List!(int) v = w[1..3];
    assert( v.length == 2 );
    assert( v[0] == 4 );
    assert( v[1] == 5 );

    // test readonly
    List!(int,ReadOnly) rv = v.readonly;
    assert( rv.length == 2 );
    assert( rv[0] == 4 );
    assert( rv[1] == 5 );
    assert( rv.head == rv[0 .. 1] );
    assert( rv.tail == rv[1 .. 2] );

    // test algorithms
    assert( v.opIn(5) == v.tail );
    assert( v.count(5) == 1 );
    assert( v.find(delegate int(inout int v){return v == 5;}) == v.tail );
    v[0 .. 1].swap(v[1..2]);
    assert( v[0] == 5 );
    assert( v[1] == 4 );
    v.fill(10);
    assert( v[0] == 10 );
    assert( v[1] == 10 );
    List!(int) vsub;
    vsub.add(4,5);
    v.copy(vsub);
    assert( v[0] == 4 );
    assert( v[1] == 5 );

    // test another node type
    List!(char[]) str;
    str.add("hello","world");
    assert( str[str.length-1] == "world" );

    // test sub-list spanning
    List!(int) tmp;
    int[10] tmp2;
    tmp2[3] = 100;
    tmp2[8] = 200;
    foreach(int xx;tmp2)
      tmp ~= xx;
    List!(int) a,b,c;
    a = tmp[3..5];
    b = tmp[7..9];
    c = tmp[a..b];
    assert( c.length == 6 );
    assert( c[0] == 100 );
    assert( c[5] == 200 );

    // CircularList testing

    CircularList!(int) cx;
    cx ~= 3;
    cx ~= 4;
    assert( cx[0] == 3 );
    assert( cx[1] == 4 );
    assert( cx.length == 2 );

    CircularList!(int) cx2;
    cx2.add(3,4);
    assert( cx == cx2 );

    // test addHead
    CircularList!(int) cy;
    cy.addHead(4);
    cy.addHead(3);

    // test ==
    assert( cx == cy );
    CircularList!(int) cw = cx.dup;
    cw ~= 5;
    assert( cx != cw);

    // test remove
    assert( cw.takeTail() == 5 );
    wlen = cw.length;
    cw.addTail(6);
    cw.removeTail();
    assert( cw.length() == wlen );
    assert( cw == cx );
    cw ~= 5;

    // test reverse lists
    CircularList!(int) cz = cy.dup;
    cz.reverse();
    assert( cz[0] == 4 );
    assert( cz[1] == 3 );

    // test foreach iteration
    foreach(size_t n, inout int val; cz) {
      val = n*10;
    }
    assert( cz[0] == 0 );
    assert( cz[1] == 10 );
    foreach(size_t n, int val; cy.backwards()) {
      assert(cx[n] == val);
    }
    n = 0;
    foreach(List!(int) itr; cy) {
      assert(itr[0] == cy[n++]);
    }

    // test slicing
    List!(int) cv = w[1..3];
    assert( cv.length == 2 );
    assert( cv[0] == 4 );
    assert( cv[1] == 5 );
  
    // test algorithms
    assert( cv.opIn(5) == v.tail );
    assert( cv.count(5) == 1 );

    // test another node type
    CircularList!(char[]) cstr;
    cstr.add("hello","world");
    assert( cstr[cstr.length-1] == "world" );

    // test sub-list spanning
    CircularList!(int,false,MallocNoRoots) ctmp;
    tmp2[3] = 100;
    tmp2[8] = 200;
    foreach(int xx;tmp2)
      ctmp ~= xx;
    List!(int,false,MallocNoRoots) ca,cb,cc;
    ca = ctmp[3..5];
    cb = ctmp[7..9];
    cc = ctmp[ca..cb];
    assert( cc.length == 6 );
    assert( cc[0] == 100 );
    assert( cc[5] == 200 );
    ctmp.clear();
    assert( ctmp.isEmpty );

    // test simple sorting
    List!(int) s1,s12;
    s1.add(40,300,-20,100,400,200);
    s12 = s1.dup;
    s1.sort();
    List!(int) s2 = List!(int).make(-20,40,100,200,300,400);
    //List!(int) s2 = s2.make(-20,40,100,200,300,400);
    assert( s1 == s2 );
    // sort a slice in-place
    s12[1..4].sort();
    s2.clear();
    s2.add(40,-20,100,300,400,200);
    assert( s12 == s2 );

    // test a large sort with default order
    List!(double) s3;
    for (int k=0;k<1000;k++) {
      s3 ~= 1.0*rand()/100000.0 - 500000.0;
    }
    List!(double) s4 = s3.dup;
    s3.sort();
    for (int k=0;k<999;k++) {
      assert( s3[k] <= s3[k+1] );
    }
    // test a large sort with custom order
    int cmp(double*x,double*y){return *x>*y?-1:*x==*y?0:1;}
    s4.sort(&cmp);
    for (int k=0;k<999;k++) {
      assert( s4[k] >= s4[k+1] );
    }

    version (MinTLVerboseUnittest) 
      printf("finished mintl.list unittest\n");
  }
}
