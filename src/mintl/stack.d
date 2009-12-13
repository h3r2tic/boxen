/** \file stack.d
 * \brief A stack container
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 1.1
 */

module mintl.stack;

private import mintl.deque;
private import mintl.arraylist;
import mintl.adapter;
import mintl.share;
import mintl.mem;

/** A stack of items of stype Value backed by a container of type ImplType.
 * Aliases push and pop allow stack operations. By default the stack is
 * backed by a Deque.
 */
struct Stack(Value, ImplType = Deque!(Value)) {

  alias Stack       ContainerType;
  alias Value       ValueType;
  alias size_t      IndexType;
  alias ImplType    AdaptType;
  const bit isReadOnly = ImplType.isReadOnly;

  ImplType impl;

  mixin MAdaptBuiltin!(impl,Stack);
  mixin MAdaptBasic!(impl,Stack);
  mixin MAdaptList!(impl,Stack);
  mixin MListCatOperators!(Stack);

  // Stack specific
  static if (!ImplType.isReadOnly) {
    alias add push;
    alias takeTail pop;
  }
  Value peek() { 
    ImplType last = impl.tail;
    return last.isEmpty ? Value.init : last[0];
  }
}

/** Convenience alias for a stack backed by an array */
template ArrayStack(Value) {
  alias Stack!(Value,ArrayList!(Value)) ArrayStack;
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;

version (MinTLUnittest) {
  import xf.mintl.list;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.stack unittest\n");
    Stack!(int) st;
    st.push(10, 20);
    assert( st.peek == 20 );
    assert( st.pop == 20 );
    assert( st[st.length - 1] == 10 );
    assert( st.pop == 10 );
    assert( st.length == 0 );

    ArrayStack!(int) st2;
    st2.push(10);
    st2 ~= 20;
    assert( st2.peek == 20 );
    assert( st2.pop == 20 );
    assert( st2[st2.length - 1] == 10 );
    assert( st2.pop == 10 );
    assert( st2.length == 0 );

    Stack!(int,List!(int)) st3;
    st3.push(10);
    st3 ~= 20;
    assert( st3.peek == 20 );
    assert( st3.pop == 20 );
    assert( st3[st3.length - 1] == 10 );
    assert( st3.pop == 10 );
    assert( st3.length == 0 );

    version (MinTLVerboseUnittest) 
      printf("finished mintl.stack unittest\n");
  }
}
