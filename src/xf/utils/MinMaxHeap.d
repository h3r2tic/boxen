/**
  * Based on tango.util.container.more.Heap:
  * 
  * Copyright:  Copyright (C) 2008 Chris Wright.  All rights reserved.
  * License:    BSD style: $(LICENSE)
  * Version:    Oct 2008: Initial release
  * Author:     Chris Wright, aka dhasenan
  *
  */


module xf.utils.MinMaxHeap;

private {
	import tango.core.Exception;
}



struct MinMaxHeap(T, bool Min)
{
        alias pop       remove;
        alias push      opCatAssign;

        // The actual data.
        private T[]     heap;
        
        // The index of the cell into which the next element will go.
        private uint    next;


        static MinMaxHeap opCall(T[] data) {
			MinMaxHeap res;
			res.heap = data;
			return res;
		}
		

        /** Inserts the given element into the heap. */
        void push (T t)
        {
                auto index = next++;
                while (heap.length <= index) {
					throw new ArrayBoundsException("The MinMaxHeap is fixed-size :S", index);
                       //heap.length = 2 * heap.length + 32;
				}

                heap [index] = t;
//                onMove (t, index);
                fixup (index);
        }

        /** Inserts all elements in the given array into the heap. */
        /+void push (T[] array)
        {
                if (heap.length < next + array.length)
                        heap.length = next + array.length + 32;

                foreach (t; array) push (t);
        }+/

        /** Removes the top of this heap and returns it. */
        T pop ()
        {
                return removeAt (0);
        }

        /** Remove the every instance that matches the given item. */
        void removeAll (T t)
        {
                // TODO: this is slower than it could be.
                // I am reasonably certain we can do the O(n) scan, but I want to
                // look at it a bit more.
                while (remove (t)) {}
        }

        /** Remove the first instance that matches the given item. 
          * Returns: true iff the item was found, otherwise false. */
        bool remove (T t)
        {
                foreach (i, a; heap)
                {
                        if (a is t || a == t)
                        {
                                removeAt (i);
                                return true;
                        }
                }
                return false;
        }

        /** Remove the element at the given index from the heap.
          * The index is according to the heap's internal layout; you are 
          * responsible for making sure the index is correct.
          * The heap invariant is maintained. */
        T removeAt (uint index)
        {
                if (next <= index)
                {
                        throw new NoSuchElementException ("MinMaxHeap :: tried to remove an"
                                ~ " element with index greater than the size of the heap "
                                ~ "(did you call pop() from an empty heap?)");
                }
                next--;
                auto t = heap[index];
                // if next == index, then we have nothing valid on the heap
                // so popping does nothing but change the length
                // the other calls are irrelevant, but we surely don't want to
                // call onMove with invalid data
                if (next > index)
                {
                        heap[index] = heap[next];
//                        onMove(heap[index], index);
                        fixdown(index);
                }
                return t;
        }

        /** Gets the value at the top of the heap without removing it. */
        T peek ()
        {
                assert (next > 0);
                return heap[0];
        }

        /** Returns the number of elements in this heap. */
        uint size ()
        {
                return next;
        }

        /** Reset this heap. */
        void clear ()
        {
                next = 0;
        }

        /** reset this heap, and use the provided host for value elements */
        void clear (T[] host)
        {
                this.heap = host;
                clear;
        }

        /** Get the reserved capacity of this heap. */
        uint capacity ()
        {
                return heap.length;
        }

        /** Reserve enough space in this heap for value elements. The reserved space is truncated or extended as necessary. If the value is less than the number of elements already in the heap, throw an exception. */
        /+uint capacity (uint value)
        {
                if (value < next)
                {
                        throw new IllegalArgumentException ("MinMaxHeap :: illegal truncation");
                }
                heap.length = value;
                return value;
        }+/

        /** Return a shallow copy of this heap. */
        MinMaxHeap clone ()
        {
                MinMaxHeap other;
                other.heap = this.heap.dup;
                other.next = this.next;
                return other;
        }

        // Get the index of the parent for the element at the given index.
        private uint parent (uint index)
        {
                return (index - 1) / 2;
        }

        // Having just inserted, restore the heap invariant (that a node's value is greater than its children)
        private void fixup (uint index)
        {
                if (index == 0) return;
                uint par = parent (index);
                if (!comp(heap[par], heap[index]))
                {
                        swap (par, index);
                        fixup (par);
                }
        }

        // Having just removed and replaced the top of the heap with the last inserted element,
        // restore the heap invariant.
        private void fixdown (uint index)
        {
                uint left = 2 * index + 1;
                uint down;
                if (left >= next)
                {
                        return;
                }

                if (left == next - 1)
                {
                        down = left;
                }
                else if (comp (heap[left], heap[left + 1]))
                {
                        down = left;
                }
                else
                {
                        down = left + 1;
                }

                if (!comp(heap[index], heap[down]))
                {
                        swap (index, down);
                        fixdown (down);
                }
        }

        // Swap two elements in the array.
        private void swap (uint a, uint b)
        {
                auto t1 = heap[a];
                auto t2 = heap[b];
                heap[a] = t2;
//                onMove(t2, a);
                heap[b] = t1;
//                onMove(t1, b);
        }

        private bool comp (T parent, T child)
        {
                static if (Min == true)
                           return parent <= child;
                else
                           return parent >= child;
        }
}


/** A minheap implementation. This will have the smallest item as the top of the heap. 
  *
  * Note: always pass by reference when modifying a heap. 
  *
*/

template MinHeap(T)
{
        alias MinMaxHeap!(T, true) MinHeap;
}

/** A maxheap implementation. This will have the largest item as the top of the heap. 
  *
  * Note: always pass by reference when modifying a heap. 
  *
*/

template MaxHeap(T)
{
        alias MinMaxHeap!(T, false) MaxHeap;
}
