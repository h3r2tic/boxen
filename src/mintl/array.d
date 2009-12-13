/** \file array.d
 * \brief Utility functions for dynamic and associative arrays.
 * 
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * revision 2.6
 */

module mintl.array;

// sort with custom compare delegate
template sort(Value:Value[]) {
  void sort(Value[] data, int delegate(Value* l, Value* r) cmp = null) {
    void swap( Value* t1, Value* t2 ) {
      Value t = *t1; *t1 = *t2; *t2 = t;
    }
    void insertionSort(Value[] data) {
      Value* head = &data[0];
      Value* tail = head+data.length;
      Value* i = head+1;
      while(i < tail) {
	Value* j = i;
	for (; j > head && cmp(j - 1,j) > 0; j--) {
	  swap(j - 1,j);
	}
	i++;
      }
    }
    void dosort(Value[] data) {
      if (data.length < 2) {
	return;
      } else if (data.length < 8) {
	insertionSort(data);
	return;
      }
      Value *head = &data[0];
      Value *tail = head+data.length-1;
      Value *p = head+1;
      Value *q = tail;
      swap(head,head+data.length/2);
      if (cmp(p,q) > 0) swap(p,q);
      if (cmp(head,q) > 0) swap(head,q);
      if (cmp(p,head) > 0) swap(p,head);
      while (1) {
	do p++; while (cmp(p, head) < 0);
	do q--; while (cmp(q, head) > 0);
	if (p > q) break;
	swap(p,q);
      }
      swap(head,q);
      if (head < q)
	dosort(head[0 .. q-head+1]);
      if (p < tail)
	dosort(p[0 .. tail-p+1]);
    }
    TypeInfo ti = typeid(Value);
    if (cmp is null) {
      cmp = cast(typeof(cmp))&ti.compare;
    }
    dosort(data);
  }
}

/** Reserve a capacity for a dynamic array. If the array already has
 * more elements or if the original length is zero it does nothing.
 * Compiler-dependent.
 * \param x the array to modify
 * \param n the requested capacity
 */
template reserve(Value : Value[]) {
  void reserve(inout Value[] x, size_t n) {
    size_t oldlen = x.length;
    if ((oldlen < n) && (oldlen > 0)) {
      x.length = n;
      x.length = oldlen;
    }
  }
}

/** Iterate backwards over a dynamic array. This function should be
 *  used on the target array in a foreach statement or
 *  or as the target to a call to toSeq <tt>x.backwards.toSeq</tt>
 *  \param x the array to iterate over.
 */
template backwards(Value : Value[]) {
  DArrayReverseIter!(Value) backwards(Value[] x) {
    DArrayReverseIter!(Value) y;
    y.x = x;
    return y;
  }
}

/* Private helper for reverse iteration */
private struct DArrayReverseIter(Value) {
  Value[] x;
  int opApply(int delegate(inout Value val) dg) {
    int res = 0;
    for (size_t n=x.length; n > 0; ) {
      res = dg(x[--n]);
      if (res) break;
    }
    return res;
  }
  int opApply(int delegate(inout size_t n, inout Value val) dg) {
    int res = 0;
    size_t cnt = 0;
    for (size_t n=x.length; n > 0; cnt++) {
      res = dg(cnt,x[--n]);
      if (res) break;
    }
    return res;
  }
}

//version = MinTLVerboseUnittest;
//version = MinTLUnittest;
version (MinTLUnittest) {
  private import std.random;
  unittest {
    version (MinTLVerboseUnittest) 
      printf("starting mintl.array unittest\n");

    int[] x;
    x.length = 1;
    reserve!(int[])(x,100);
    int[] y = x;
    x.length = 90;
    assert( cast(int*)x == cast(int*)y );
    version (MinTLVerboseUnittest) 
      printf("pass\n");

    int[] t1,t2;
    t1.length = 4;
    t2.length = 4;
    for(int k=0;k<4;k++) t1[k] = k*100;
    foreach(size_t n, int val; backwards!(int[])(t1)) {
      t2[n] = val;
    }
    assert( t1.reverse == t2 );
    version (MinTLVerboseUnittest) 
      printf("pass\n");

    double[int] c;
    c[100] = 1.1;
    c[300] = 2.2;
    c[-100] = 3.3;
    double v;
    assert( 100 in c );
    assert( !(200 in c) );
    assert( 300 in c );
    for (int k=0;k<1000;k++) {
      c[k*100] = 1;
    }

    // test simple sorting
    static int[] data = [40,300,-20,100,400,200];
    int[] s1 = data.dup;
    sort!(int[])(s1);
    static int[] s2 = [-20,40,100,200,300,400];
    assert( s1 == s2 );

    // test a large sort with default order
    double[] s3;
    for (int k=0;k<1000;k++) {
      s3 ~= 1.0*rand()/100000.0 - 500000.0;
    }
    double[] s4 = s3.dup;
    sort!(double[])(s3);
    for (int k=0;k<999;k++) {
      assert( s3[k] <= s3[k+1] );
    }
    // test a large sort with custom order
    int cmp(double*x,double*y){return *x>*y?-1:*x==*y?0:1;}
    sort!(double[])(s4,&cmp);
    for (int k=0;k<999;k++) {
      assert( s4[k] >= s4[k+1] );
    }

    version (MinTLVerboseUnittest) 
      printf("finished mintl.array unittest\n");
  }
}
