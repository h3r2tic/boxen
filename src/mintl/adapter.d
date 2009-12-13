/** \file adapter.d
 * \brief Mixins for adapter containers like stack, queue, set.
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 1.1
 */

module mintl.adapter;

template MAdaptBuiltin(alias impl, Container) {
  size_t length() { return impl.length; }
  int opEquals(Container c) { return impl == c.impl; }
}

template MAdaptBasic(alias impl, Container) {
  bool isEmpty() { return impl.isEmpty; }
  Container.ValueType opIndex(Container.IndexType n) { return impl[n]; }
  static if (!Container.isReadOnly) {
    void opIndexAssign(Container.ValueType v, Container.IndexType n) { impl[n] = v; }
  }
  int opApply(int delegate(inout Container.ValueType x) dg){return impl.opApply(dg);}
  int opApply(int delegate(inout Container.IndexType, inout Container.ValueType x) dg){return impl.opApply(dg);}
  Container dup() {
    Container res;
    res.impl = impl.dup;
    return res;
  }
}

template MAdaptList(alias impl, Container) {
  static if (!Container.isReadOnly) {
  void addHead(Container.ValueType v) {impl.addHead(v);}
  void addHead(Container v) {impl.addHead(v.impl);}
  void addTail(Container.ValueType v) {impl.addTail(v);}
  void addTail(Container v) {impl.addTail(v.impl);}
  Container.ValueType takeTail() {return impl.takeTail();}
  void removeTail() {impl.removeTail();}
  Container.ValueType takeHead() {return impl.takeHead();}
  void removeHead() {impl.removeHead();}
  void clear(){impl.clear();}
  }
  int opCmp(Container c) { return impl.opCmp(c.impl); }
}

