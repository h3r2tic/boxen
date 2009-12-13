/** \file sorting.d
 * \brief Mixins for sorting random-access and sequential-access containers
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 1.0
 */

module mintl.sorting;

// mixin for sorting random-access containers
// quicksort with insertion sort for short lists
template MRandomAccessSort(Container, alias list) {
  void sort(int delegate(Container.ValueType* l, Container.ValueType* r) cmp = null) {
    void swap(Container.ValueType* t1, Container.ValueType* t2 ) {
      Container.ValueType t = *t1; *t1 = *t2; *t2 = t;
    }
    void insertionSort(Container data) {
      size_t i = 1;
      while(i < data.length) {
	size_t j = i;
	Container.ValueType* jp = data.lookup(j);
	Container.ValueType* j1p;
	while (j > 0 && cmp((j1p=data.lookup(j-1)),jp) > 0) {
	  swap(j1p,jp);
	  --j;
	  jp = j1p;
	}
	i++;
      }
    }
    void dosort(Container data) {
      if (data.length < 2) {
	return;
      } else if (data.length < 8) {
	insertionSort(data);
	return;
      }
      size_t tail = data.length-1;
      size_t p = 1;
      size_t q = tail;
      Container.ValueType* headptr = data.lookup(0);
      Container.ValueType* pptr = data.lookup(p);
      Container.ValueType* qptr = data.lookup(q);
      swap(headptr,data.lookup(data.length/2));
      if (cmp(pptr,qptr) > 0) swap(pptr,qptr);
      if (cmp(headptr,qptr) > 0) swap(headptr,qptr);
      if (cmp(pptr,headptr) > 0) swap(pptr,headptr);
      while (1) {
	do p++; while (cmp(data.lookup(p), headptr) < 0);
	do q--; while (cmp(data.lookup(q), headptr) > 0);
	if (p > q) break;
	swap(data.lookup(p),data.lookup(q));
      }
      swap(headptr,data.lookup(q));
      if (0 < q)
	dosort(data[0 .. q+1]);
      if (p < tail)
	dosort(data[p .. tail+1]);
    }
    TypeInfo ti = typeid(Container.ValueType);
    if (cmp is null) {
      cmp = cast(typeof(cmp))&ti.compare;
    }
    dosort(list);
  }
}

// mixin for sorting sequential-access containers
// using mergesort customized for doublly-linked lists
// TODO: allow singly-linked lists, too
template MSequentialSort(Container, alias head_, alias tail_) {
  void dosort(out Container.Node* newhead,
	      out Container.Node* newtail,
	      int delegate(Container.SortType* l, Container.SortType* r) cmp = null) {
    void link(Container.Node* a, Container.Node* b) {
      if (a) a.next = b;
      if (b) b.prev = a;
    }
    if (cmp is null) {
      TypeInfo ti = typeid(Container.SortType);
      cmp = cast(typeof(cmp))&ti.compare;
    }
    Container.Node* head = head_;
    Container.Node* tail = tail_;
    Container.Node* headprev = head.prev;
    Container.Node* i,j,e,itail;
    i = tail;
    tail = tail.next; // one past tail
    i.next = null;
    int depth;
    size_t ilen, jlen, len = 1;
    while (1) {
      i = head;
      depth = 0;
      itail = null;
      head = null;
      while (i) {
	depth++;
	j = i;
	ilen = 0;
	for (size_t k = 0; k < len; k++) {
	  ilen++;
	  j = j.next;
	  if (!j) break;
	}
	jlen = len;
	while (ilen > 0 || (jlen > 0 && j)) {
	  if (ilen == 0) {
	    e = j; j = j.next; jlen--;
	  } else if (jlen == 0 || !j ||
		     cmp(i.sortLookup(),j.sortLookup()) <= 0) {
	    e = i; i = i.next; ilen--;
	  } else {
	    e = j; j = j.next; jlen--;
	  }
	  if (itail) {
	    link(itail,e);
	  } else {
	    head = e;
	  }
	  itail = e;
	}
	i = j;
      }
      itail.next = null;
      if (depth <= 1) {
	link(itail,tail);
	newtail = itail;
	link(headprev,head);
	newhead = head;
	return;
      }
      len *= 2;
    }
  }
}
