module xf.nucleus.TypeConversion;

private {
	import xf.Common;
	import xf.nucleus.TypeSystem;
	import xf.utils.IntrusiveHash;
	import xf.utils.MinMaxHeap;
	import xf.mem.StackBuffer;
}


struct SearchItem {
}


	bool findConversion(
			Semantic from,
			Semantic to,
			//void delegate(SemanticConverter, Semantic afterConv) sink,
			int* retTotalCost = null
	) {
		scope stack = new StackBuffer;

		
		struct HeapItem {
			SearchItem*	item;
			word		cost;
			
			int opCmp(HeapItem rhs) {
				return this.cost - rhs.cost;
			}
		}

		// TODO: make the limits dynamic somehow... or just big enough :P
		enum {
			maxHeapItems = 1000,
			minHashBuckets = 1000
		}

		auto openSet = MinHeap!(HeapItem)(
			stack.allocArray!(HeapItem)(maxHeapItems)
		);
		
		auto closedSet = IntrusiveHashMap!(Semantic, SearchItem*).opCall(
			stack.allocArray!(Semantic*)(goodHashSize(minHashBuckets))
		);


		assert (false);		// TODO
		/+
		/+Stdout("Registered converters: {").newline;
		foreach (c; &converters) {
			Stdout.formatln("\t{}", c.toString);
		}
		Stdout("}").newline;+/
		
		if (from == to) {
			//Stdout.formatln("nothing to do, lol");
			if (retTotalCost !is null) {
				*retTotalCost = 0;
			}
			return true;
		}

//		Stdout.formatln("Finding a conversion '{}' -> '{}'", from.toString, to.toString);
		
		struct HeapItem {
			SearchItem*	item;
			int				cost;
			
			int opCmp(HeapItem rhs) {
				return this.cost - rhs.cost;
			}
		}
		
		MinHeap!(HeapItem) openSet; {
			auto item = SearchItem.freeListAlloc();
			item.sem = from;
			item.prev = null;
			item.cost = 0;
			item.isFinal = false;
			openSet ~= HeapItem(item, 0);
		}
		
		scope closedSet = new HashMap!(Semantic, SearchItem*);
		scope (exit) {
			foreach (k, v; closedSet) {
				v.freeListDispose;
				v.sem.freeNoGC();
			}
		}
		
		while (openSet.size > 0) {
			auto item = openSet.pop();
			//Stdout.formatln("popped cost: {}", item.cost);
			
			if (item.cost > item.item.cost) {
				continue;
			}
			
			//if (item.item.sem == to) {
			if (item.item.isFinal) {
				if (sink !is null) {
					// reverse the list in place
					SearchItem* next = item.item.prev;
					SearchItem* prev = null;
					for (SearchItem* ptr = item.item; ptr !is null; ptr = next) {
						next = ptr.prev;
						ptr.prev = prev;
						prev = ptr;
					}
					
					//Stdout.formatln("omfg! I've found it, I've found it!!");

					auto first = prev;

					for (auto it = first; it !is null; it = it.prev) {
						if (it.conv !is null) {
							sink(it.conv, it.sem);
//							Stdout.format(" -> {} ({}->{})", it.conv.name, it.conv.from, it.conv.to);
						} else {
//							Stdout.format("SRC");
						}
					}
//					Stdout.newline;
				}
				
				if (retTotalCost !is null) {
					*retTotalCost = item.cost;
				}
				return true;
			}
			
			foreach (conv, extraCost; applicableConverters(item.item.sem)) {
				//Stdout.formatln("trying out converter {} ({}->{})", conv.toString, conv.from, conv.to);
				
				Semantic converted;
				conv.convertTraits(item.item.sem, (Trait trait) {
					converted.addTraitNoGC(trait);
				});

				int newCost = item.cost + conv.cost + extraCost;
				
				Semantic converted2;
				bool isFinal = canPassSemanticFor(converted, to, true, &newCost, &converted2);
				
				if (isFinal) {
					//Stdout.formatln("adjusting semantic {} -> {} (for target {})", converted.toString, converted2.toString, to.toString);
					converted.freeNoGC();
					converted = converted2;
				} else {
					converted2.freeNoGC();
				}

				if (auto existing = converted in closedSet) {
					if (newCost < (*existing).cost) {
						(*existing).cost = newCost;
						(*existing).prev = item.item;
						(*existing).conv = conv;
						(*existing).isFinal = isFinal;
						//Stdout.formatln("updating {} with cost {}", converted.toString, newCost);
						openSet ~= HeapItem(*existing, newCost);
					} else {
						converted.freeNoGC();
					}
				} else {
					auto n = SearchItem.freeListAlloc();
					n.sem = converted;
					n.prev = item.item;
					n.cost = newCost;
					n.conv = conv;
					n.isFinal = isFinal;
					//Stdout.formatln("pushing {} with cost {}", converted.toString, newCost);
					openSet ~= HeapItem(n, newCost);
					closedSet[n.sem] = n;
				}
			}
		}
		
		return false;+/
	}
