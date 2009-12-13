/** \file mem.d
 * \brief Allocators for custom container memory management
 *
 * Written by Ben Hinkle and released to the public domain, as
 * explained at http://creativecommons.org/licenses/publicdomain
 * Email comments and bug reports to ben.hinkle@gmail.com
 *
 * version 1.0
 */

module mintl.mem;

private {
  import tango.stdc.stdlib;
  import tango.core.Memory : GC;
  import tango.core.Exception : onOutOfMemoryError;
}

/** An Allocator is a type containing 8 symbols malloc, calloc,
 * realloc, free and the corresponding GC-aware versions gcMalloc,
 * gcCalloc, gcRealloc and gcFree. Containers will call the GC-aware
 * functions on blocks that may hold roots and otherwise will call the
 * regular functions. Allocators are expected to throw OutOfMemory if
 * the allocation fails. Be aware than when using an allocator with
 * a container one must call the container <tt>clear()</tt> function
 * to free the memory.
 *
 * The two predefined allocators Malloc and MallocNoRoots use
 * std.c.stdlib.malloc to perform allocations. The MallocNoRoots
 * ignores any requests by the container to register roots with the
 * GC. The MallocNoRoots allocator should only be used with containers
 * that the user knows will never contain any roots (e.g. ArrayList!(int))
 */

/** Malloc and throw OutOfMemory if fails. */
void* mallocWithCheck(size_t s) {
  void* p = malloc(s);
  if (!p)
    onOutOfMemoryError();
  return p;
}

/** Calloc and throw OutOfMemory if fails. */
void* callocWithCheck(size_t n, size_t s) {
  void* p = calloc(n,s);
  if (!p)
    onOutOfMemoryError();
  return p;
}

/** Realloc and throw OutOfMemory if fails. */
void* reallocWithCheck(void*p, size_t s) {
  p = realloc(p,s);
  if (!p)
    onOutOfMemoryError();
  return p;
}

/** Free pointer. */
void dfree(void*p) {
  free(p);
}

/** Malloc and register the range with GC.   */
void* gcMalloc(size_t s) {
  void* p = mallocWithCheck(s);
  GC.addRange(p,s);
  return p;
}

/** Calloc and register the range with GC.   */
void* gcCalloc(size_t n, size_t s) {
  void* p = callocWithCheck(n,s);
  GC.addRange(p,n*s);
  return p;
}

/** Realloc and register the range with GC.   */
void* gcRealloc(void* p, size_t s) {
  if (p)
    GC.removeRange(p);
  p = reallocWithCheck(p,s);
  GC.addRange(p,s);
  return p;
}

/** Deregister the range with GC and free.   */
void gcFree(void* p) { 
  if (p)
    GC.removeRange(p);
  free(p);
}

// Default Allocator
struct GCAllocator{
  alias void malloc;
  alias void calloc;
  alias void realloc;
  alias void free;
  alias void gcMalloc;
  alias void gcCalloc;
  alias void gcRealloc;
  alias void gcFree;
}

// An allocator that uses malloc
struct Malloc {
  alias mallocWithCheck malloc;
  alias callocWithCheck calloc;
  alias reallocWithCheck realloc;
  alias dfree free;
  alias .gcMalloc gcMalloc;
  alias .gcCalloc gcCalloc;
  alias .gcRealloc gcRealloc;
  alias .gcFree gcFree;
}

// An allocator that uses malloc and assumes allocations have no roots
struct MallocNoRoots {
  alias mallocWithCheck malloc;
  alias callocWithCheck calloc;
  alias reallocWithCheck realloc;
  alias dfree free;
  alias mallocWithCheck gcMalloc;
  alias callocWithCheck gcCalloc;
  alias reallocWithCheck gcRealloc;
  alias dfree gcFree;
}

