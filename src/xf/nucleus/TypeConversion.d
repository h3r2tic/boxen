module xf.nucleus.TypeConversion;

private {
	import xf.Common;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Function;
	import xf.nucleus.Param;
	import xf.utils.IntrusiveHash;
	import xf.utils.MinMaxHeap;
	import xf.mem.StackBuffer;
	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;
}



struct SemanticConverter {
	Function	func;
	int			cost;
	

	// TODO: will false ever be needed?
	const bool	acceptAdditionalTraits = true;

	Semantic* sourceSemantic() {
		assert (2 == func.numParams);
		assert (func.params[0].hasPlainSemantic);
		assert (func.params[0].isInput);
		return func.params[0].semantic();
	}

	void convert(Semantic* input, Semantic* output) {
		assert (2 == func.numParams);

		final iPar = &func.params[0];
		final oPar = &func.params[1];

		assert (iPar.hasPlainSemantic);

		assert (iPar.isInput);
		assert (!oPar.isInput);
		
		if (oPar.hasPlainSemantic) {
			*output = *oPar.semantic();
		} else {
			findOutputSemantic(
				oPar,

				// getFormalParamSemantic
				(cstring name) {
					if (name != iPar.name) {
						error(
							"SemanticConverter.convert: output param refers to a"
							" nonexistent formal parameter '{}'.",
							name
						);
						assert (false);
					} else {
						return *iPar.semantic();
					}
				},

				// getActualParamSemantic
				(cstring name) {
					if (name != iPar.name) {
						error(
							"SemanticConverter.convert: output param refers to a"
							" nonexistent actual parameter '{}'.",
							name
						);
						assert (false);
					} else {
						return *input;
					}
				},
				
				output
			);
		}
	}
}

private alias int delegate(int delegate(ref SemanticConverter)) SemanticConverterIter;


bool findConversion(
		Semantic from,
		Semantic to,
		
		SemanticConverterIter semanticConverters,

		// Note: the Semantic yielded by this sink dg cannot be retained
		// because it's allocated within this function's StackBuffer
		void delegate(SemanticConverter*, Semantic* afterConv) sink = null,
		
		int* retTotalCost = null
) {
	if (from == to) {
		if (retTotalCost !is null) {
			*retTotalCost = 0;
		}
		return true;
	}

	scope stack = new StackBuffer;

	struct SearchItem {
		Semantic			sem;
		SearchItem*			prev;
		int					cost;
		SemanticConverter*	conv;
		bool				isFinal;
	}
	
	struct HeapItem {
		SearchItem*	item;
		word		cost;
		
		int opCmp(HeapItem rhs) {
			return this.cost - rhs.cost;
		}
	}

	// TODO: make the limits dynamic somehow... or just "big enough" :P
	enum {
		maxHeapItems = 1024,
		minHashBuckets = 1024
	}

	auto searchItems = stack.allocArray!(SearchItem)(maxHeapItems);

	auto openSet = MinHeap!(HeapItem)(
		stack.allocArray!(HeapItem)(maxHeapItems)
	);

	SearchItem* allocSearchItem() {
		if (0 == searchItems.length) {
			error("TypeConversion.findConversion: Out of search items in the freelist.");
		}
		
		final res = &searchItems[0];
		searchItems = searchItems[1..$];
		return res;
	}

	{
		final item = allocSearchItem();
		item.sem = from;
		item.prev = null;
		item.cost = 0;
		item.isFinal = false;
		openSet ~= HeapItem(item, 0);
	}
	
	auto closedSet = IntrusiveHashMap!(Semantic, SearchItem*)(
		stack.allocArray!(Semantic*)(goodHashSize(minHashBuckets))
	);

	void* allocator(uword bytes) {
		return stack.allocRaw(bytes);
	}

	// log.trace("Finding a conversion '{}' -> '{}'", from.toString, to.toString);

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
						sink(it.conv, &it.sem);
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
		
		foreach (
				conv,
				extraCost;
				applicableConverters(semanticConverters, &item.item.sem)
		) {
			//Stdout.formatln("trying out converter {} ({}->{})", conv.toString, conv.from, conv.to);

			// There's a chance that the converted semantic is already in our
			// closed set and the cost is lequal. The stack2 will dump it if it's not used.
			scope stack2 = new StackBuffer;

			auto converted = Semantic(&allocator);
			conv.convert(&item.item.sem, &converted);
			
			int newCost = item.cost + conv.cost + extraCost;

			bool isFinal = canPassSemanticFor(
				converted,
				to,
				true,
				&newCost
			);

			if (auto existing_ = &converted in closedSet) {
				SearchItem* existing = *existing_;
				assert (existing !is null);
				
				if (newCost < existing.cost) {
					existing.cost = newCost;
					existing.prev = item.item;
					existing.conv = conv;
					existing.isFinal = isFinal;
					//Stdout.formatln("updating {} with cost {}", converted.toString, newCost);
					openSet ~= HeapItem(existing, newCost);

					// The converted Semantic is used
					stack2.forgetMemory();
				} else {
					// converted will die at the end of stack2's scope
				}
			} else {
				auto n = allocSearchItem();
				n.sem = converted;
				n.prev = item.item;
				n.cost = newCost;
				n.conv = conv;
				n.isFinal = isFinal;
				//Stdout.formatln("pushing {} with cost {}", converted.toString, newCost);
				openSet ~= HeapItem(n, newCost);
				closedSet[&n.sem] = n;

				// The converted Semantic is used
				stack2.forgetMemory();
			}
		}
	}
	
	return false;
}


// It's not a class! It's not a struct! It's a fruct! OMAGAWD!!12
private struct applicableConverters {
	SemanticConverterIter	all;
	Semantic*				source;
	
	int opApply(int delegate(ref SemanticConverter*, ref int extraCost) sink) {
		foreach (ref c; this.all) {
			int extraCost = c.cost;
			if (canPassSemanticFor(
					*source,
					*c.sourceSemantic,
					c.acceptAdditionalTraits,
					&extraCost
			)) {
				auto cp = &c;		// lame, D1, lame...
				if (int r = sink(cp, extraCost)) {
					return r;
				}
			}
		}
		
		return 0;
	}
}
