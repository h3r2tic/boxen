/** \file queue.d
 * \brief A queue container
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 1.1
 */

module mintl.queue;

private import mintl.deque;
private import mintl.arraylist;
private import mintl.arrayheap;
import mintl.adapter;
import mintl.share;

/** A queue of items of stype Value backed by a container of type ImplType.
 * Aliases put and take allow queue operations. By default the queue is
 * backed by a Deque.
 */
struct Queue(Value, ImplType = Deque!(Value)) {

  alias Queue       ContainerType;
  alias Value       ValueType;
  alias size_t      IndexType;
  alias ImplType    AdaptType;
  const bit isReadOnly = ImplType.isReadOnly;

  ImplType impl;

  mixin MAdaptBuiltin!(impl,Queue);
  mixin MAdaptBasic!(impl,Queue);
  mixin MAdaptList!(impl,Queue);
  mixin MListCatOperators!(Queue);

  // Queue specific
  static if (!ImplType.isReadOnly) {
    alias addTail put;
    alias takeHead take;
  }
  Value peek() { 
    return impl.isEmpty ? Value.init : impl[0];
  }
}

/** Convenience alias for a queue backed by an array */
template ArrayQueue(Value) {
  alias Queue!(Value,ArrayList!(Value)) ArrayQueue;
}

/** Convenience alias for a queue backed by a heap */
template PriorityQueue(Value) {
  alias Queue!(Value,ArrayHeap!(Value)) PriorityQueue;
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;

version (MinTLUnittest) {
  import mintl.list;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.queue unittest\n");

    Queue!(int) q;
    q ~= 10;
    q ~= 20;
    assert( q.peek == 10 );
    assert( q.take == 10 );
    assert( q[0] == 20 );
    assert( q.take == 20 );
    assert( q.length == 0 );

    ArrayQueue!(int) st2;
    st2.put(10);
    st2 ~= 20;
    assert( st2.peek == 10 );
    assert( st2.take == 10 );
    assert( st2[0] == 20 );
    assert( st2.take == 20 );
    assert( st2.length == 0 );

    Queue!(int,List!(int)) st3;
    st3.put(10);
    st3 ~= 20;
    assert( st3.peek == 10 );
    assert( st3.take == 10 );
    assert( st3[0] == 20 );
    assert( st3.take == 20 );
    assert( st3.length == 0 );

    version (MinTLVerboseUnittest) 
      printf("finished mintl.queue unittest\n");
  }
}
