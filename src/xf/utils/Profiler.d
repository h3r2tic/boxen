module xf.utils.Profiler;

private {
	import xf.utils.HardwareTimer;

	// for the ProfilingDataFormatter
	import tango.stdc.stdio : sprintf;
	import tango.stdc.stringz : fromStringz;
}



/*
	not sure if this stuff makes any sense with multithreading... :P
*/

struct ProfilingData {
	int		parent = -1;
	int		numCalls = 0;
	long		timeMicros = 0;
	char[]	name;
}


ProfilingData*[]	profilingData;


void resetProfilingData() {
	foreach (pd; profilingData) {
		with (*pd) {
			parent = -1;
			numCalls = 0;
			timeMicros = 0;
		}
	}
}



private {
	int nextProfileBlockId = 0;
	

	__thread HardwareTimer	hwTimer__;
	//ThreadLocal!(long)	threadLostTime;
	__thread int			currentBlock = -1;
	
	
	HardwareTimer hwTimer() {
		if (hwTimer__ !is null) {
			return hwTimer__;
		} else {
			return hwTimer__ = new HardwareTimer;
		}
	}
}


enum ProfileOpts {
	Default = 0,
	NoTime = 1
}


template profile(char[] name, ProfileOpts opts = ProfileOpts.Default) {
	// TODO
	
	T profile(T)(T delegate() dg) {
		/+static ProfilingData	data;
		static int				id;

		static bool initialized = false;
		if (!initialized) {
			initialized = true;
			id = .nextProfileBlockId++;
			data.name = name;
			profilingData ~= &data;
		}		
		
		++data.numCalls;	// BUG: non thread-safe. it might use atomic operations
		
		static if (0 == opts & ProfileOpts.NoTime) {
			long lostTime, startTime;
			HardwareTimer timer = hwTimer;
			timer.micros_Time_TimeDelta(startTime, lostTime);
			//threadLostTime.val = threadLostTime.val + lostTime;
		}
		
		int parentBlock = currentBlock;
		
		if (parentBlock != id) {
			data.parent = parentBlock;
		}
		
		currentBlock = id;
		scope (exit) {
			currentBlock = parentBlock;
			
			static if (0 == opts & ProfileOpts.NoTime) {
				long endTime = timer.timeMicros();
				data.timeMicros += endTime - startTime;
			}
		}
		+/
		return dg();
	}
}



/+
scope class ProfilingDataFormatter {
	Node[]	nodes;
	Node		root;


	int opApply(int delegate(ref int row, ref int col, ref Node node) layout) {
		prepare;
		
		int voffset = 0;
		int worker(Node* node, int hoffset, int nesting = 0) {
			for (; node !is null; node = node.sibling, ++voffset) {
				if (node !is &root) {
					if (auto res = layout(voffset, hoffset, *node)) {
						return res;
					}
				}
				
				++voffset;
				if (auto res = worker(node.child, hoffset + 1, nesting + 1)) {
					return res;
				}
			}
			
			return 0;
		}
		
		return worker(&root, -1);
	}
	
	
	~this() {
		nodes.free();
	}


	private void prepare() {
		if (nodes.length < profilingData.length) {
			nodes.realloc(profilingData.length, false);
		}
		
		root = Node.init;
		root.text = `root`;
		
		foreach (ref n; nodes) {
			n = Node.init;
		}

		ulong totalMicros = 0; {
			foreach (id, pd; profilingData) {
				if (0 == pd.numCalls) continue;
				
				if (-1 == pd.parent) {
					totalMicros += pd.timeMicros;
					break;
				}
			}
		}
		
		foreach (id, pd; profilingData) {
			if (0 == pd.numCalls) continue;

			Node* parent;
			Node* node = &nodes[id];
			
			if (-1 == pd.parent) {
				parent = &root;
			} else {
				parent = &nodes[pd.parent];
			}
			
			node.sibling = parent.child;
			parent.child = node;
			
			node.treeTimeFraction = node.timeFraction = cast(float)(cast(real)pd.timeMicros / totalMicros);
			node.numCalls = pd.numCalls;
			node.timeMicros = pd.timeMicros;
		}
		
		float subChildTime(Node* node) {
			float sum = 0.f;
			
			for (; node !is null; node = node.sibling) {
				float childrenFrac = subChildTime(node.child);
				sum += node.timeFraction;
				
				if (node !is &root) {
					node.timeFraction -= childrenFrac;
				}
			}
			
			return sum;
		}
		
		subChildTime(&root);
		
		float bottleneckTime = 0.f;
		int bottleneckNode = -1;
		foreach (ni, ref n; nodes) {
			if (n.timeFraction > bottleneckTime) {
				bottleneckTime = n.timeFraction;
				bottleneckNode = ni;
			}
		}
		if (bottleneckNode != -1) {
			nodes[bottleneckNode].bottleneck = true;
		}

		foreach (id, pd; profilingData) {
			if (0 == pd.numCalls) continue;

			Node* node = &nodes[id];

			sprintf(
					node.textBuf.ptr,
					"%.*s: %d * %2.1f ms = %2.1f ms : %1.1f%% (%1.1f%% tree)",
					pd.name,
					pd.numCalls,
					0.001f * pd.timeMicros / pd.numCalls,
					0.001f * pd.timeMicros,
					node.timeFraction * 100.f,
					node.treeTimeFraction * 100.f
				);
				
			node.text = .fromStringz(node.textBuf.ptr);
		}
	}


	private struct Node {
		Node*	child;
		Node*	sibling;
		
		char[256]	textBuf;
		char[]		text;
		float			treeTimeFraction = 0.f;
		float			timeFraction = 0.f;
		int			numCalls = 0;
		ulong		timeMicros = 0;
		bool			bottleneck;
	}
}
+/
