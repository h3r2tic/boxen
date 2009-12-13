/** \file share.d
 * \brief Mixin templates and exceptions shared between modules.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 */

module mintl.share;

public import tango.core.Vararg;
//public import std.boxer;

alias bool bit;
const bit ReadOnly = true;

//version = WithBox;

/** Return the length of an argument in bytes. */
size_t va_argumentLength(size_t baseLength)
{
    return (baseLength + int.sizeof - 1) & ~(int.sizeof - 1);
}

/** A mixin for overloading ~, ~=, and add
 *  Assumes List class implements dup, addTail, addHead
 */
template MListCatOperators(List) {

  /** Appends the specified items to the tail of the target list by
   * calling <tt>addTail</tt> repeatedly.
   */
  void add(...) {
    vadd(_arguments,cast(ArgPtrType)_argptr);
  }
	version(GNU) {
		alias char* ArgPtrType;
		
		void vadd(TypeInfo[] arguments, char* argptr) {
			for (int k=0;k<arguments.length;k++) {
				TypeInfo tiv = typeid(List.ValueType);
				TypeInfo tik = arguments[k];
				if (tik is tiv) {
					addTail(va_arg!(List.ValueType)(argptr));
				} else {
					version (WithBox) {
						Box b = box(tik,argptr);
						addTail(unbox!(List.ValueType)(b));
						argptr += va_argumentLength(tik.tsize());
					} else {
						throw new Exception("illegal add argument");
					}
				}
			}
		}
	} else {
		alias void* ArgPtrType;
		
		void vadd(TypeInfo[] arguments, void* argptr) {
			for (int k=0;k<arguments.length;k++) {
				TypeInfo tiv = typeid(List.ValueType);
				TypeInfo tik = arguments[k];
				if (tik is tiv) {
					addTail(va_arg!(List.ValueType)(argptr));
				} else {
					version (WithBox) {
						Box b = box(tik,argptr);
						addTail(unbox!(List.ValueType)(b));
						argptr += va_argumentLength(tik.tsize());
					} else {
						throw new Exception("illegal add argument");
					}
				}
			}
		}
	}
	

  /** Construct a list with specified contents */
  static List make(...) {
    List res;
    res.vadd(_arguments,cast(ArgPtrType)_argptr);
    return res;
  }

  /** Add a value N times */
  void addN(uint n, List.ValueType v) {
    while (n--)
      addTail(v);
  }

  /** Appends an item to the tail of the target list.  If the target
   * list is a sub-list call addAfter instead of ~= to insert an item
   * after a sub-list.
   */
  List opCatAssign(List.ValueType v) {
    addTail(v);
    return *this;
  }

  /** Appends an item to the tail of a duplicate of the target list.    */
  List opCat(List.ValueType v) {
    List res = this.dup;
    res.addTail(v);
    return res;
  }

  /** Appends a list to the tail of the target list.    */
  List opCatAssign(List v) {
    addTail(v.dup);
    return *this;
  }

  /** Appends a duplicate of the input list to the tail of a duplicate
   * of the target list.
   */
  List opCat(List v) {
    List res = this.dup;
    res.addTail(v.dup);
    return res;
  }

  /** Appends an item to the tail of a duplicate of the target list.    */
  List opCat_r(List.ValueType v) {
    List res = this.dup;
    res.addHead(v);
    return res;
  }
}

/** \class IndexOutOfBoundsException
 * \brief An exception thrown when attempting to index past the head
 * or tail of a list or when attempting to remove an element from an
 * empty list.
 */
class IndexOutOfBoundsException: Exception {
  this(char[] str) { super(str); }
  this() { super("Index out of bounds"); }
}

/** A mixin for associative array add function  */
template MAddAA(AA) {
  private import tango.core.Traits : ParameterTupleOf;

  /** Inserts the specified items into the target AA by calling
   * x[key]=value repeatedly.
   */
  void add(...) {
    vadd(_arguments,_argptr);
  }
  void vadd(TypeInfo[] arguments, void* argptr) {
    for (int k=0;k<arguments.length;k++) {
      TypeInfo tik = typeid(AA.IndexType);
      if (arguments[k] == tik) {
				// workaround for GNU compilers using std.c.stdarg
				alias ParameterTupleOf!(va_arg!(AA.IndexType))[0] VaList;
				VaList vaList = cast(VaList)argptr;
        AA.IndexType key = va_arg!(AA.IndexType)(vaList);
        k++;
        (*this)[key] = va_arg!(AA.ValueType)(vaList);
				argptr = cast(void*)vaList;
      } else {
	version (WithBox) {
	Box b = box(tik,argptr);
        AA.IndexType key = unbox!(AA.IndexType)(b);
        k++;
	TypeInfo tiv = arguments[k];
        b = box(tiv,argptr);
	(*this)[key] = unbox!(AA.ValueType)(b);
	argptr += va_argumentLength(tiv.tsize());
	} else {
	  throw new Exception("illegal add argument");
	}
      }
    }
  }

  /** Construct a container with specified contents */
  static AA make(...) {
    AA res;
    res.vadd(_arguments,_argptr);
    return res;
  }
}

/** Mixin template for defining opApply variations */
template MOpApplyImpl(Container) {

  int opApplyNoKey(int delegate(inout Container.ValueType n) dg){
    return opApplyNoKeyStep(dg);
  }

  int opApplyWithKey(int delegate(inout Container.IndexType n, inout Container.ValueType x) dg){
    return opApplyWithKeyStep(dg);
  }

  int opApplyIter(int delegate(inout Container.SliceType n) dg){
    return opApplyIterStep(dg);
  }

  int opApplyBackwards(int delegate(inout Container.ValueType x) dg){
    return opApplyNoKeyStep(dg,-1);
  }

  int opApplyWithKeyBackwards(int delegate(inout Container.IndexType n, inout Container.ValueType x) dg){
    return opApplyWithKeyStep(dg,-1);
  }

  int opApplyIterBackwards(int delegate(inout Container.SliceType x) dg){
    return opApplyIterStep(dg,-1);
  }

}

/** Mixin template for defining opApply variations for
 * backward iteration. Use in conjunction with mixing in 
 * MOpApplyHelpers into the primary structure.
 */
template MReverseImpl(Iter,Container = Iter) {
  Container* list;

  int opApply(int delegate(inout Iter.ValueType x) dg){
    return list.opApplyNoKeyStep(dg,-1);
  }

  int opApply(int delegate(inout Iter.IndexType n, inout Iter.ValueType x) dg){
    return list.opApplyWithKeyStep(dg,-1);
  }

  int opApply(int delegate(inout Iter x) dg){
    return list.opApplyIterStep(dg,-1);
  }
}

/** Mixin for list algorithms */
template MListAlgo(Container, alias list) {

  // return first occurrence of v
  Container.SliceType opIn(Container.ValueType v) {
    Container.SliceType res;
    TypeInfo ti = typeid(Container.ValueType);
    foreach(Container.SliceType i; list) {
      Container.ValueType iv = i.value;
      if (ti.equals(&v,&iv)) {
	res = i;
	break;
      }
    }
    return res;
  }

  // count number of occurrences of v
  uint count(Container.ValueType v) {
    uint res;
    TypeInfo ti = typeid(Container.ValueType);
    foreach(inout Container.ValueType val; list) {
      if (ti.equals(&v,&val))
	res++;
    }
    return res;
  }

  static if (!Container.isReadOnly) {
  // swap values with v
  void swap(Container v) {
    if (v.isEmpty) return;
    Container.SliceType jend = v.tail;
    Container.SliceType j = v.head;
    TypeInfo ti = typeid(Container.ValueType);
    foreach(Container.SliceType i; list) {
      Value v = i.value;
      i.value = j.value;
      j.value = v;
      if (j == jend) break;
      j.next();
    }
  }

  // fill the container with a value
  void fill(Container.ValueType v) {
    foreach(inout Container.ValueType val; list) {
      val = v;
    }
  }

  // copy the contents of v to this container
  void copy(Container v) {
    if (v.isEmpty) return;
    Container.SliceType i = v.head;
    Container.SliceType j = v.tail;
    foreach(inout Container.ValueType val; list) {
      val = i.value;
      if (i == j) break;
      i.next();
    }
  }

  } // !isReadOnly

  // find first occurrence where delegate is true
  Container.SliceType find(int delegate(inout Value v) dg) {
    Container.SliceType res;
    TypeInfo ti = typeid(Container.ValueType);
    foreach(Container.SliceType i; list) {
      Container.ValueType v = i.value;
      if (dg(v)) {
	res = i;
	break;
      }
    }
    return res;
  }
  
}
