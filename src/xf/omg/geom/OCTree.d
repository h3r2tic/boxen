/**
	An OCTree designed for location-based data adding and searching
	
	1. Create the OCTree with a pre-specified AABB
	2. Add some data to the tree
	3. Query the data by position and max distance
	4. Goto 2, 3 or finish
*/

module xf.omg.geom.OCTree;

private {
	import xf.omg.core.LinearAlgebra;
	import xf.omg.geom.AABB;
	import xf.utils.Memory;
	
	import tango.io.Stdout;
}



template OCTree(Data) {
	static assert (is(Data == struct));
	static assert (is(typeof(Data.position) == vec3));
	
	
	const int maxDataPerNode = 50;
	const int maxTreeDepth = 10;
	
	
	struct Leaf {
		Data[]	data() {
			return data_[0..numData];
		}
		
		
		void add(ref Data d) {
			data_.append(d, &numData);
		}
		
		
		void free() {
			xf.utils.Memory.free(data_);
			numData = 0;
		}
		
		
		private {
			Data[]	data_;
			uint		numData;
		}
	}


	struct Node {
		bool isLeaf() {
			return (cast(size_t)children & 1) == 1;
		}
		
		
		Node* child(int i) {
			Node* ptr = cast(Node*)(cast(size_t)children & (~cast(size_t)1));
			assert (ptr !is null);
			return &ptr[i];
		}
		
		
		Leaf* leaf() {
			assert (isLeaf);
			return cast(Leaf*)(cast(size_t)children & (~cast(size_t)1));
		}
		
		
		void setLeaf(Leaf* ptr) {
			size_t p = cast(size_t)ptr;
			assert ((p & 1) == 0);
			p |= 1;
			children = cast(Node*)p;
			assert (isLeaf);
		}
		
		
		private {
			Node*	children;
		}
	}


	class Tree {
		Node		root;
		AABB	box;
		
		
		this(AABB box) {
			this.box = box;
			Leaf[] tmp;
			tmp.alloc(1);
			root.setLeaf(&tmp[0]);
		}
		
		
		struct DataIter {
			Tree	tree;
			vec3	pos;
			float	maxDist;
			
			int opApply(int delegate(ref Data) apply) {
				float maxDist2 = maxDist * maxDist;
				
				struct StackItem {
					Node	node;
					vec3	center;
					vec3	size;
				}
				
				const int stackSize = 64;
				StackItem[stackSize]	stack;
				int							stackp;
				
				void			push(StackItem i) { stack[stackp++] = i; }
				StackItem	pop() { assert(stackp > 0); return stack[--stackp]; }
				
				push(StackItem(tree.root, tree.box.center, tree.box.size));
				while (stackp != 0) {
					auto item = pop();
					
					if (item.node.isLeaf) {
						auto leaf = item.node.leaf();
						foreach (ref d; leaf.data) {
							float dist2 = (d.position - pos).sqLength;
							if (dist2 <= maxDist2) {
								if (auto res = apply(d)) {
									return res;
								}
							}
						}
					} else {
						vec3 off = pos - item.center;
						
						bool[8] checkMasks = void;
						checkMasks[] = 1;
						
						for (int c = 0; c < 3; ++c) {
							if (off.cell[c] > maxDist) {	// skip the 'left' side
							
								// TODO: unroll with static foreach
								for (int x = 0; x < 2; ++x) {
									if (c != 0 || 0 == x) for (int y = 0; y < 2; ++y) {
										if (c != 1 || 0 == y) for (int z = 0; z < 2; ++z) {
											if (c != 2 || 0 == z) {
												checkMasks[x + 2 * y + 4 * z] = false;
											}
										}
									}
								}
								
							}
							
							if (off.cell[c] < -maxDist) {	// skip the 'right' side
							
								// TODO: unroll with static foreach
								for (int x = 0; x < 2; ++x) {
									if (c != 0 || 1 == x) for (int y = 0; y < 2; ++y) {
										if (c != 1 || 1 == y) for (int z = 0; z < 2; ++z) {
											if (c != 2 || 1 == z) {
												checkMasks[x + 2 * y + 4 * z] = false;
											}
										}
									}
								}
								
							}
						}
						
						/+Stdout.format(`offset: {} check masks: [`, off.toString);
						foreach (cm; checkMasks) {
							Stdout.format(` {}`, cm);
						}
						Stdout.formatln(` ]`);+/
						
						foreach (i, check; checkMasks) {
							if (!check) continue;
							
							vec3 newSize = item.size * 0.5f;
							vec3 newCenter = void;
							
							if (0 == (i & 1)) newCenter.x = item.center.x - newSize.x;
							else newCenter.x = item.center.x + newSize.x;
							if (0 == (i & 2)) newCenter.y = item.center.y - newSize.y;
							else newCenter.y = item.center.y + newSize.y;
							if (0 == (i & 4)) newCenter.z = item.center.z - newSize.z;
							else newCenter.z = item.center.z + newSize.z;
							
							push(StackItem(*item.node.child(i), newCenter, newSize));
						}
					}
				}
				
				return 0;
			}
		}
		
		
		DataIter findData(vec3 pos, float maxDist) {
			return DataIter(this, pos, maxDist);
		}
		
		
		Node* alloc8Nodes() {
			size_t siz = Node.sizeof * 8 + 2;
			void* ptr = cMalloc(siz);
			if (cast(size_t)ptr & 1) ptr = cast(void*)(cast(size_t)ptr + 1);
			auto res = cast(Node*)ptr;
			foreach (ref n; res[0..8]) {
				n = Node.init;
			}
			return res;
		}
		
		
		Leaf* allocLeaf() {
			size_t siz = Leaf.sizeof + 2;
			void* ptr = cMalloc(siz);
			if (cast(size_t)ptr & 1) ptr = cast(void*)(cast(size_t)ptr + 1);
			auto res = cast(Leaf*)ptr;
			*res = Leaf.init;
			return res;
		}
		
		
		void addData(Data data) {
			Node*	node = &root;
			vec3 	center = box.center;
			vec3 	size = box.size;
			int		depth = 1;
			
			while (!node.isLeaf) {
				//Stdout.formatln(`Finding a leaf...`);
				
				int idx = 0;
				vec3 off = data.position - center;
				size *= 0.5f;
				
				if (off.x <= 0) {
					center.x -= size.x;
				} else {
					center.x += size.x;
					idx |= 1;
				}

				if (off.y <= 0) {
					center.y -= size.y;
				} else {
					center.y += size.y;
					idx |= 2;
				}

				if (off.z <= 0) {
					center.z -= size.z;
				} else {
					center.z += size.z;
					idx |= 4;
				}
				//Stdout.formatln(`Offset: {}, Recursing to {}`, off.toString, idx);
				
				node = node.child(idx);
				++depth;
			}

			//Stdout.formatln(`Leaf candidate found.`);
			assert (node !is null);
			assert (node.isLeaf);
			
			auto leaf = node.leaf();
			assert (leaf !is null);
			//Stdout.formatln(`Leaf found...`);
			
			if (leaf.data.length + 1 > maxDataPerNode && depth < maxTreeDepth) {
				//Stdout.formatln(`Splitting the leaf`);

				node.children = alloc8Nodes();
				foreach (ref ch2; node.children[0..8]) {
					auto leaf2 = allocLeaf();
					//Stdout.formatln(`Allocated a leaf: {}`, leaf2);
					ch2.setLeaf(leaf2);
				}
				//Stdout.formatln(`Added 8 child nodes`);
				
				for (int i = 0; i < leaf.data.length + 1; ++i) {
					Data* dptr = (i == leaf.data.length ? &data : &leaf.data[i]);
					
					vec3 off = dptr.position - center;
					int cls = 0;
					
					if (off.x > 0) {
						cls |= 1;
					}
					if (off.y > 0) {
						cls |= 2;
					}
					if (off.z > 0) {
						cls |= 4;
					}
					
					//Stdout.formatln(`Adding point {} to leaf {}`, dptr.position.toString, i);
					auto l = node.children[cls].leaf();
					assert (l !is null);
					//Stdout.formatln(`... got the leaf (addr={}) ...`, l);
					l.add(*dptr);
					//Stdout.formatln(`Point added`);
				}
				
				//Stdout.formatln(`Freeing the leaf`);
				leaf.free();
				cFree(leaf);
			} else {
				//Stdout.formatln(`Adding data to the leaf`);
				leaf.add(data);
			}
		}
	}
}



unittest {
	class OCUnitTest {
		import tango.math.random.Kiss;

		struct IrradData {
			vec3	position;
			int	idx;
		}

		alias OCTree!(IrradData) IrradOCTree;


		this() {
			scope ocTree = new IrradOCTree.Tree(AABB(vec3(-1, -1, -1), vec3(1, 1, 1)));
			scope rand = new Kiss;

			float frand() {
				return (1.0 / uint.max) * rand.natural;
			}
			vec3 vrand() {
				return vec3((frand - 0.5f) * 2.f, (frand - 0.5f) * 2.f, (frand - 0.5f) * 2.f);
			}
			
			IrradData[] pts = new IrradData[10_000];
			foreach (i, ref p; pts) {
				p.idx = i;
				p.position = vrand;
				ocTree.addData(p);
			}
			
			foreach (p; pts) {
				bool found = false;
				foreach (ref data; ocTree.findData(p.position, 0.04f)) {
					if (data.idx == p.idx) {
						found = true;
						break;
					}
				}
				if (!found) {
					ocTree.addData(p);
					assert (false);
				}
			}

			Stdout.formatln(`OCTree test 0 passed`);
			
			for (int i = 0; i < 1000; ++i) {
				vec3 p = vrand();
				int[] foundBrute;
				int[] foundOCTree;
				
				float range = frand() * 0.5f + 0.01f;
				float range2 = range * range;
				
				foreach (ref data; pts) {
					if ((data.position - p).sqLength <= range2) {
						foundBrute ~= data.idx;
					}
				}
				
				foreach (ref data; ocTree.findData(p, range)) {
					foundOCTree ~= data.idx;
				}
				
				foundBrute.sort;
				foundOCTree.sort;
				
				// There exists a possibility that it might fail, since the OCTree does slightly different range calculations
				// thus numerical instability might get into play. In such a case, the unittest might be tweaked to accept a few errors.
				assert (foundBrute == foundOCTree);
				
				delete foundBrute;
				delete foundOCTree;
			}

			Stdout.formatln(`OCTree test 1 passed`);
		}
	}
	
	
	new OCUnitTest;
}
