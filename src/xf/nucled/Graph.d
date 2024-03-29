module xf.nucled.Graph;

private {
	import xf.Common;

	import xf.nucleus.Param;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.kdef.model.IKDefUtilParser;
	import xf.nucleus.kdef.model.KDefInvalidation;
	import xf.nucleus.kdef.model.IKDefRegistry;
	import xf.nucleus.kdef.Common : KDefGraph = GraphDef, KDefGraphNode = GraphDefNode, ParamListValue, GraphDefValue, KernelDefValue, KernelDef, KernelImpl;
	import xf.nucleus.Value;
	import xf.nucleus.Function;
	import xf.nucleus.Nucleus;
	import xf.nucled.DataProvider;
	
	import xf.hybrid.Hybrid;
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.omg.core.LinearAlgebra;
	import xf.nucled.Widgets;
	import xf.nucled.Misc;
	import xf.nucled.Settings;
	import xf.nucled.Log : log = nucledLog;
	import xf.nucled.DynamicGridInput;
	import xf.utils.Array : arrayRemove = remove;

	import xf.mem.ChunkQueue;
	import xf.mem.Gather;

	static import xf.utils.Array;
	
	//import xf.utils.OldCfg : Config = Array;
	import xf.core.Registry;
	import tango.text.convert.Format;
	import TextUtil = tango.text.Util;
	import tango.io.stream.Format;
	import tango.io.vfs.model.Vfs : VfsFolder, VfsFile;
	import tango.io.device.File : FileConduit = File;
	import tango.io.stream.Lines : Lines;
	
	import tango.io.Stdout;
}



class Graph {
	this(GraphMngr mngr) {
		this._mngr = mngr;
		mngr.register(this);
	}
	
	
	void addNode(GraphNode node) {
		_nodes ~= node;
		node._mngr = this._mngr;
	}
	
	
	void clearNodes() {
		// TODO: clean up the nodes?
		_nodes.length = 0;
	}
	
	
	int iterAllConnections(int delegate(ref Connection) dg) {
		foreach (n; _nodes) {
			foreach (o; n.outgoing) {
				if (auto r = dg(o)) {
					return r;
				}
			}
		}
		
		return 0;
	}
	
	
	GraphNode[] nodes() {
		return _nodes;
	}
	

	void doGUI() {
		GraphNode nodeToDelete = null;
		foreach (n; _nodes) {
			if (!n.doGUI) {
				nodeToDelete = n;
			}
		}
		
		if (nodeToDelete !is null) {
			_nodes.arrayRemove(nodeToDelete);
			nodeToDelete.unlink;
		}
	}
	
	
	void dump(KDefGraph kdef, IKDefRegistry reg) {
		kdef._name = null;	// TODO
		kdef._nodes = kdef.mem.allocArrayNoInit!(KDefGraphNode)(this.nodes.length);
		kdef._nodeNames = kdef.mem.allocArrayNoInit!(cstring)(this.nodes.length);

		foreach (ni, n; this.nodes) {
			VarDef[1] vars;
			vars[0] = VarDef("type", kdef.mem._new!(IdentifierValue)(n.typeName()));

			kdef._nodes[ni] = kdef.mem._new!(KDefGraphNode)(
				vars[],
				kdef.mem._allocator
			);
			n.dump(kdef._nodes[ni], reg);
			kdef._nodeNames[ni] = kdef.mem.dupString(n.label);
		}

		{
			alias GraphDef.NodeConnection NC;

			gatherArrays!(NC)(kdef.mem,
			(void delegate(lazy NC) gen) {
				foreach (n; nodes) {
					foreach (con; n.outgoing) {
						foreach (flow; con.flow) {
							if (depOutputConnectorName == flow.from) {
								gen(NC(
									kdef._nodes[xf.utils.Array.indexOf(nodes, con.from)],
									kdef._nodes[xf.utils.Array.indexOf(nodes, con.to)]
								));
							}
						}
					}
				}
			},
			(NC[] nodeCons) {
				kdef.nodeConnections = nodeCons;
			});
		}

		{
			alias GraphDef.NodeFieldConnection NFC;

			gatherArrays!(NFC)(kdef.mem,
			(void delegate(lazy NFC) gen) {
				foreach (n; nodes) {
					foreach (con; n.outgoing) {
						foreach (flow; con.flow) {
							if (depOutputConnectorName != flow.from) {
								gen(NFC(
									kdef._nodes[xf.utils.Array.indexOf(nodes, con.from)],
									kdef._nodes[xf.utils.Array.indexOf(nodes, con.to)],

									// duplicated later --->
									flow.from,
									flow.to
								));
							}
						}
					}
				}
			},
			(NFC[] nodeCons) {
				foreach (ref c; nodeCons) {
					// <---
					c.from = kdef.mem.dupString(c.from);
					c.to = kdef.mem.dupString(c.to);
				}
				kdef.nodeFieldConnections = nodeCons;
			});
		}

		{
			alias GraphDef.NoAutoFlow NAF;

			gatherArrays!(NAF)(kdef.mem,
			(void delegate(lazy NAF) gen) {
				foreach (ni, n; nodes) {
					foreach (i; n.inputs) {
						if (i.noAutoFlow) {
							gen(NAF(
								kdef._nodes[ni],
								kdef.mem.dupString(i.name)
							));
						}
					}
				}
			},
			(NAF[] noAutoFlow) {
				kdef.noAutoFlow = noAutoFlow;
			});
		}
	}
	
	
	void load(KDefGraph source) {
		Stdout.formatln("Graph.load() called");
		
		GraphNode[void*] def2node;
		
		foreach (nname, kdefNode; source.nodes) {
			auto node = new GraphNode(kdefNode);
			def2node[cast(void*)kdefNode] = node;
			node.label = nname.dup;
			addNode(node);
			Stdout.formatln("loading a graph node");
		}
		
		foreach (ncon; source.nodeConnections) {
			new Connection(
				def2node[cast(void*)ncon.from],
				def2node[cast(void*)ncon.to],
				DataFlow(depOutputConnectorName, depInputConnectorName)
			);
		}
		
		foreach (nfcon; source.nodeFieldConnections) {
			new Connection(
				def2node[cast(void*)nfcon.fromNode],
				def2node[cast(void*)nfcon.toNode],
				DataFlow(nfcon.from.dup, nfcon.to.dup)
			);
		}

		foreach (naf; source.noAutoFlow) {
			final node = def2node[cast(void*)naf.toNode];
			foreach (ref input; node.inputs) {
				if (naf.to == input.name) {
					input.noAutoFlow = true;
				}
			}
		}
		
		foreach (lo; loadObservers) {
			lo(this);
		}
	}


	protected {
		GraphMngr	_mngr;
		GraphNode[]	_nodes;
	}
	
	public {
		void delegate(Graph)[]	loadObservers;
	}
}




class ConnectorInfo {
	char[]		name;
	GraphNode	node;
	vec2		windowPos = vec2.zero;
	bool		noAutoFlow = false;
	
	
	this(Param param, GraphNode node) {
		this.name = param.name.dup;
		this.node = node;
	}
}




interface NodeContents {
	void	doGUI();
	void	refresh();
}



struct DataFlow {
	char[]	from;
	char[]	to;
}



class Connection {
	this(GraphNode from, GraphNode to, DataFlow[] flow ...) {
		this.from = from;
		this.to = to;
		this.flow = flow.dup;
		
		from.addOutgoingConnection(this);
		to.addIncomingConnection(this);
	}
	

	void unlink() {
		void remFrom(ref Connection[] cl) {
			foreach (i, c; cl) {
				if (this is c) {
					cl[i] = cl[$-1];
					cl = cl[0..$-1];
					return;
				}
			}
			assert (false, `not found`);
		}
		
		assert (from !is null);
		assert (to !is null);
		remFrom(from.outgoing);
		remFrom(to.incoming);
	}

	
	GraphNode	from;
	GraphNode	to;
	DataFlow[]	flow;
}


ConnectorInfo find(ConnectorInfo[] arr, char[] name) {
	foreach (ref x; arr) {
		if (x.name == name) {
			return x;
		}
	}
	return null;
}



class GraphNode {
	enum Type {
		Calc,
		Data,
		GPUWrap,
		Demux,
		Query,
		Input,
		Output
	}

	
	this(Type t) {
		_mem.initialize();
		this._id = g_nextId++;
		this.data = new DataCommons;
		this.data.params._allocator = &_mem.pushBack;
		this.type = t;
		
		if (type != Type.Input && type != Type.Data) {
			Param meh;
			// works because the arg is a const string
			meh.unsafeOverrideName(depInputConnectorName);
			this.inputs ~= new ConnectorInfo(meh, this);
		}
		
		if (type != Type.Output) {
			Param meh;
			// works because the arg is a const string
			meh.unsafeOverrideName(depOutputConnectorName);
			this.outputs ~= new ConnectorInfo(meh, this);
		}
	}
	

	this(Type t, char[] kernelName) {
		this(t);
		this._kernelName = kernelName;
		if (isKernelBased) {
			createKernelNodeInputs();
		}
	}


	private void createKernelNodeInputs() {
		auto impl = getKernel();
		
		if (KernelImpl.Type.Kernel == impl.type) {
			final kernel = impl.kernel;
			final func = kernel.func;

			foreach (param; func.params) {
				Stdout.formatln(`Creating a param '{}'`, param.name);
				if (param.isInput) {
					inputs ~= new ConnectorInfo(param, this);
				} else {
					outputs ~= new ConnectorInfo(param, this);
				}
			}
		} else {
			final graph = cast(GraphDef)impl.graph;
			foreach (name, n; graph.nodes) {
				if ("input" == n.type) {
					foreach (param; n.params) {
						inputs ~= new ConnectorInfo(param, this);
					}
				} else if ("output" == n.type) {
					foreach (param; n.params) {
						outputs ~= new ConnectorInfo(param, this);
					}
				}
			}
		}
	}
	
	
	this (KDefGraphNode cfg) {
		//_mem.initialize();

		char[] identVal(char[] name) {
			return cfg.getVar(name).as!(IdentifierValue).value;
		}

		this(typeFromString(identVal("type")));
		
		if (auto sp = cfg.getVar("center")) {
			this.spawnPosition = vec2.from(sp.as!(Vector2Value).value);
		}
		
		// there's also the size, but we'll ignore it for now
		
		if (this.isKernelBased) {
			final val = cfg.getVar("kernel");
			if (auto kd = cast(KernelDefValue)val) {
				_kernelName = "inline";
				_isInline = true;
				_inlineKernel = kd.kernelDef;
				//assert (false, "TODO: inline kernels");
			} else if (auto gd = cast(GraphDefValue)val) {
				_kernelName = "inline";
				_isInline = true;
				_inlineGraph = gd.graphDef;
				//assert (false, "TODO: inline graphs");
			} else {
				_kernelName = identVal("kernel").dup;
			}

			createKernelNodeInputs();
			// TODO: ParamValueInfo
		} else {
			foreach (param; cfg.params) {
				this.data.params.add(param);
				paramValueInfo ~= ParamValueInfo();
				
				if (Type.Output == this.type) {
					inputs ~= new ConnectorInfo(param, this);
				} else {
					outputs ~= new ConnectorInfo(param, this);
				}
			}
		}
	}


	// TODO: mem
	void addInput(Param p) {
		inputs ~= new ConnectorInfo(p, this);
		if (!this.isKernelBased) {
			this.data.params.add(p).dir = ParamDirection.In;
		}
		paramValueInfo ~= ParamValueInfo();
	}
		

	// TODO: mem
	void addOutput(Param p) {
		outputs ~= new ConnectorInfo(p, this);
		if (!this.isKernelBased) {
			this.data.params.add(p).dir = ParamDirection.Out;
		}
		paramValueInfo ~= ParamValueInfo();
	}

	
	uint id() {
		return this._id;
	}
	
	
	int iterInputs(int delegate(ref int i, ref ConnectorInfo) dg) {
		int i;
		foreach (ref x; inputs) {
			if (auto r = dg(i, x)) {
				return r;
			}
			++i;
		}
		return 0;
	}
	

	int iterOutputs(int delegate(ref int i, ref ConnectorInfo) dg) {
		int i;
		foreach (ref x; outputs) {
			if (auto r = dg(i, x)) {
				return r;
			}
			++i;
		}
		return 0;
	}
	
	
	/+char[] title() {
		return Format("{} ({}) : {}", _funcName == "main" ? _kernelName : _kernelName ~ ":" ~ _funcName, this.id, primLevelStr);
	}+/
	
	void getTitle(Cb)(Cb res) {
		char[256] buf;
		uint bufPtr = 0;
		auto sink = (char[] s) {
			uint to = bufPtr+s.length;
			if (to > buf.length) {
				to = buf.length;
			}
			buf[bufPtr..to] = s;
			bufPtr = to;
			return bufPtr;
		};
		
		char[] label = _kernelName;
		switch (type) {
			case Type.Data: label = "Data"; break;
			case Type.Input: label = "Input"; break;
			case Type.Output: label = "Output"; break;
			default: break;
		}
		Format.convert(sink, "{} ({})", label, this.id);
		
		res(buf[0..bufPtr]);
	}
	
	
	/+char[] primLevelStr() {
		return CPU ? "cpu" : (primLevel == PrimLevel.Vertex ? "vtx" : (primLevel == PrimLevel.Fragment ? "frag" : "wtf"));
	}
	
	
	void setPrimLevel(char[] str) {
		switch (str) {
			case "cpu":
				CPU = true;
				break;
			case "vtx":
				CPU = false;
				primLevel = PrimLevel.Vertex;
				break;
			case "frag":
				CPU = false;
				primLevel = PrimLevel.Fragment;
				break;
			default: assert (false, str);
		}
	}+/
	
	
	void dump(KDefGraphNode kdef, IKDefRegistry reg) {
		if (this.isKernelBased) {
			kdef.kernelImpl = getKernel();
		} else {
			kdef.params = data.params;
		}
	}
	
	
	char[] typeName() {
		switch (this.type) {
			case Type.Calc:		return "kernel";
			case Type.Data:		return "data";
			case Type.Input:	return "input";
			case Type.Output:	return "output";
			default: assert (false);
		}
	}
	
	
	static Type typeFromString(char[] type) {
		switch (type) {
			case "kernel":		return Type.Calc;
			case "data":		return Type.Data;
			case "input":		return Type.Input;
			case "output":		return Type.Output;
			default: assert (false, type);
		}
	}
	
	
	bool doGUI() {
		auto box = _widget = GraphNodeBox(this.id);
		getTitle((char[] t) { box.label = t; });
				
		this.currentCenter = box.globalOffset + box.size * 0.5f;
		this.currentSize = box.size;
		
		if (!box.initialized) {
			box.parentOffset = spawnPosition;

			switch (this.type) {
				case Type.Calc:
					break;
				default:
					box.enableStyle(this.typeName);
					break;
			}
			
			box.addHandler(&clickHandler);
		} else {
			this.spawnPosition = box.parentOffset;
		}
		
		int inputToRemove = -1;
		
		box.open(`inputs`);
		foreach (i, ref data; &iterInputs) {
			if (Type.Demux == this.type) {
				if (i >= inputs.length / 2) {
					break;
				}
			}
			
			HBox(i) [{
				DataConnector con;
				if (!data.noAutoFlow) {
					con = DataConnector();
					con.layoutAttribs("vexpand");
				}
				
				if (showDataNames) {
					final label = Label().text(data.name).fontSize(10).valign(1).layoutAttribs("vexpand vfill");
					if (con) {
						label.style.color.value = vec4(1, 1, 1, 1);
					} else {
						label.style.color.value = vec4(1, 1, 1, 0.2);
					}
					auto brk = ConnectionBreaker();
					brk.layoutAttribs("vexpand");
					if (brk.clicked) {
						inputToRemove = i;
					}
				}

				if (con) {
					con.input = true;
					con.ci = data;
					con.mouseButtonHandler = &_mngr.handleMouseButton;
					data.windowPos = con.globalOffset + con.size * 0.5f;
				}
			}].layoutAttribs = "hexpand hfill";
		}
		gui.close;
		
		if (showContents && contents !is null) {
			box.open(`contents`);
			contents.doGUI();
			gui.close;
		}
		
		int outputToRemove = -1;
		
		box.open(`outputs`);
			foreach (i, ref data; &iterOutputs) {
			HBox(i) [{
				Dummy().layoutAttribs("hexpand hfill");
				if (showDataNames) {
					auto brk = ConnectionBreaker();
					brk.layoutAttribs("vexpand");
					if (brk.clicked) {
						outputToRemove = i;
					}
					Label().text(data.name).fontSize(10).valign(1).layoutAttribs("vexpand vfill");
				}

				auto con = DataConnector();
				con.layoutAttribs("vexpand");
				con.input = false;
				con.ci = data;
				con.mouseButtonHandler = &_mngr.handleMouseButton;
				data.windowPos = con.globalOffset + con.size * 0.5f;
			}].layoutAttribs = "hexpand hfill";
		}
		gui.close;
		
		if (inputToRemove != -1) {
			bool removed = removeIncomingConnectionsTo(inputs[inputToRemove].name);
			if (!removed) {
				inputs[inputToRemove].noAutoFlow ^= true;
			}
		}
		if (outputToRemove != -1) {
			removeOutgoingConnectionsFrom(outputs[outputToRemove].name);
		}
		
		/+bool allowGPU = this.type != Type.GPUWrap;
		if (allowGPU) {
			box.open(`bottom`); {
				bool allowCPU = this.type != Type.Demux && this.type != Type.Query;
				
				XorSelector grp;
				
				int cpuIndex = -1;
				XCheck cpu;
				if (allowCPU) {
					cpu			= XCheck().text("c").group(grp);
					cpuIndex	= 0;
				}
				auto vertex		= XCheck().text("v").group(grp);
				auto fragment	= XCheck().text("f").group(grp);

				if (this.CPU) {
					assert (cpu !is null);
					DefaultOption = cpu;
				} else {
					if (PrimLevel.Fragment == this.primLevel) {
						DefaultOption = fragment;
					} else {
						DefaultOption = vertex;
					}
				}
				
				this.CPU = cpuIndex == grp.index;
				
				if (cpuIndex+1 == grp.index) {
					this.primLevel = PrimLevel.Vertex;
				}
				else if (cpuIndex+2 == grp.index) {
					this.primLevel = PrimLevel.Fragment;
				}
			}
			gui.close;
		} else {
			assert (this.CPU);
		}+/

		bool wasEditingProps = _editingProps;
		if (box.doubleClicked) {
			_editingProps = true;
		}
		
		if (_editingProps) {
			auto frame = FloatingWindow(this.id);
			frame [{
				doEditorGUI(!wasEditingProps, frame.wantsToClose);
			}];
			//frame.text = this.title;
			getTitle((char[] t) { frame.text = t; });
			if (frame.wantsToClose) {
				_editingProps = false;
			}
			
			if (!wasEditingProps) {
				frame.parentOffset = box.parentOffset + vec2(5, box.size.y+5);
			}
		}
		
		return !box.deleteClicked;
	}
	
	
	void addOutgoingConnection(Connection con) {
		outgoing ~= con;
	}


	void addIncomingConnection(Connection con) {
		incoming ~= con;
	}
	
	
	bool isKernelBased() {
		switch (this.type) {
			case Type.Calc:
			case Type.GPUWrap:
			case Type.Demux:
			case Type.Query:
				return true;
				
			case Type.Data:
			case Type.Input:
			case Type.Output:
				return false;

			default: assert (false);
		}
	}


	KernelImpl getKernel() {
		if (_isInline) {
			return _inlineGraph
				? KernelImpl(_inlineGraph)
				: KernelImpl(_inlineKernel);
		} else {
			return kdefRegistry.getKernel(kernelName);
		}
	}
	
	
	bool		_choosingImpl;
	//QuarkDef	_quarkBeingEdited;
	
	void doEditorGUI(bool justOpened, bool closing) {
		if (isKernelBased) {
			if (!_inlineGraph) {
				doCodeEditorGUI(justOpened, closing);
			} else {
				// TODO: graph editor
			}
		} else {
			doDataEditorGUI(justOpened, closing);
		}
	}
	
	
	char[] safeName(char[] prev, char[] name) {
		if (!data.params.get(name)) {
			return name;
		} else {
			if (prev.length > 0) {
				return prev;
			}
			
			for (int i = 1; i < 10000; ++i) {
				auto tmp = Format("{}{}", name, i);
				if (!data.params.get(tmp)) {
					return tmp;
				}
			}
		}
		assert (false);
	}
	
	
	static class QuarkSciEditor : SciEditor {
		// in the loaded source
		uint		firstByte;
		uint		lastByte;
		KDefModule	kdefMod;

		
		void editorSaveHandler() {
			if (kdefMod is null) {
				return;
			}
			
			auto sourceVfsFile = _outer.getVfsFile(kdefMod);

			char[] text; {
				auto sourceFile = sourceVfsFile.input;
				scope (exit) sourceFile.close;
				text = cast(char[])sourceFile.load();
			}

			// TODO: check for potential external modifications to the file
			
			try {
				if (sourceVfsFile.exists) {
					sourceVfsFile.remove;
				}
			} catch {}		// we don't want failz here. better try to write the contents anyway when shit hits the fan

			try {
				sourceVfsFile.create;
			} catch {}		// ditto

			auto dstFile = sourceVfsFile.output;
			scope (exit) dstFile.flush.close;
			dstFile.write(text[0..firstByte] ~ this.text ~ text[lastByte..$]);
		}
		

		override protected EventHandling handleKey(KeyboardEvent e) {
			if (KeySym.s == e.keySym && (e.modifiers & e.modifiers.CTRL) != 0) {
				if (e.sinking && e.down) {
					this.editorSaveHandler();
				}
				return EventHandling.Stop;
			} else {
				return super.handleKey(e);
			}
		}
		
		GraphNode _outer;
		mixin MWidget;
	}
	
	
	VfsFile getVfsFile(KDefModule mod) {
		assert (mod !is null);
		final vfs = kdefRegistry.kdefFileParser.getVFS();
		assert (vfs !is null);
		
		if (auto sourceVfsFile = vfs.file(mod.filePath)) {
			log.trace("mod file: {} [ {} ]", sourceVfsFile.name, sourceVfsFile.toString);
			return sourceVfsFile;
		} else {
			log.error("Could not get load the source for module: '{}'.", mod.filePath);
			return null;
		}
	}
	
	
	void doCodeEditorGUI(bool justOpened, bool closing) {
		//assert (quark !is null);
		
		auto sci = QuarkSciEditor();
		sci._outer = this;
		
		if (justOpened) {
			KernelDef kernel = _isInline
				? _inlineKernel
				: kdefRegistry.getKernel(_kernelName).kernel;
			
			if (kernel) {
				if (auto func = cast(Function)kernel.func) {
					if (func.code._lengthBytes > 0) {
						if (auto mod = cast(KDefModule)func.code._module) {
							if (auto sourceVfsFile = getVfsFile(mod)) {
								auto sourceFile = sourceVfsFile.input;
								scope (exit) sourceFile.close;
								
								char[] text = cast(char[])sourceFile.load();

								uint first = func.code._firstByte;
								uint last = first + func.code._lengthBytes;

								// expand the range to include all the spaces and
								// tabs preceding the first token in the code
								char c;
								while (
									first > 0 &&
									((c = text[first-1]) == ' ' || c == '\t')
								) --first;
								
								sci.text = text[first..last];

								sci.firstByte = first;
								sci.lastByte = last;
								sci.kdefMod = mod;
							} else {
								log.warn("Failed to load code for the kernel '{}': unable to load file.", _kernelName);
							}
						} else {
							log.warn("Failed to load code for the kernel '{}': _module is null.", _kernelName);
						}
					}
				} else {
					log.info("Can't edit kernel '{}': it is abstract.", _kernelName);
				}
			} else {
				log.warn("Failed to get the kernel '{}' for a code editor.", _kernelName);
			}

			sci.grabKeyboardFocus();
		}
		
		sci.userSize = vec2(300, 80);
	}
	
	
	void doDataEditorGUI(bool justOpened, bool closing) {
		auto grid = DynamicGridInput();
		
		struct UserData {
			char[][int] semanticsEdited;
		}
		
		UserData* userData = justOpened ? null : cast(UserData*)grid.userData;
		if (userData is null) {
			grid.userData = userData = new UserData;
		}
		
		if (justOpened) {
			grid.popupMsg = null;
		}
		
		DynamicGridInputModel model;
		model.onAddRow = {
			char[] newName = safeName(null, "noname");
			if (Type.Output == this.type) {
				auto p = data.params.add(ParamDirection.In, newName);
				p.hasPlainSemantic = true;
				p.type = "void";
				inputs ~= new ConnectorInfo(*p, this);
			} else {
				auto p = data.params.add(ParamDirection.Out, newName);
				p.hasPlainSemantic = true;
				p.type = "void";
				outputs ~= new ConnectorInfo(*p, this);
			}
			paramValueInfo ~= ParamValueInfo();
		};
		model.onRemoveRow = (int i) {
			grid.popupMsg = null;
			if (i < data.params.length) {
				onDeleteParam(data.params[i].name);
			}
		};
		model.onCellChanged = (int row, int column, char[] val) {
			Param* p = data.params[row];
			grid.popupMsg = null;
			
			bool semanticChanged = false;

			// TODO: paramValueInfo
			
			switch (column) {
				case 0:
					char[] newName = safeName(p.name, val.dup);
					onRenameParam(p.name, newName);
					p.name = newName;
					break;
				case 1:
					auto str = val.dup;
					userData.semanticsEdited[row] = str;
					str = TextUtil.trim(str);

					if (str.length > 0) {
						auto parser = create!(IKDefUtilParser)();
						parser.parse_ParamSemantic(str, (Semantic res) {
							p.semantic.clearTraits();
							
							// HACK: this is ugly. manage allocators
							// in some other way
							*p.semantic() = res.dup(&_mem.pushBack);
						});
						delete parser;
					} else {
						p.semantic.clearTraits();
					}
					
					semanticChanged = true;
					break;
				default: assert (false);
			}
			
			if (semanticChanged) switch (column) {
				case 1:
					grid.popupCol = 1;
					grid.popupRow = row;
					grid.popupMsg = p.semantic.toString.dup;
				default:
					break;
			}
		};
		model.getNumRows = delegate int(){
			return data.params.length;
		};
		model.getNumColumns = {
			return 2;
		};
		model.getCellValue = (int row, int column) {
			if (row < data.params.length) {
				Param* p = data.params[row];
				switch (column) {
					case 0:
						return p.name;
					case 1:
						if (auto s = row in userData.semanticsEdited) {
							return *s;
						} else {
							return p.semantic.toString();
						}
					default: assert (false);
				}
			} else {
				return cast(char[])null;
			}
		};
		
		grid.doGUI(justOpened, model);
	}
	
	
	void onRenameParam(char[] from, char[] to) {
		foreach (con; outgoing) {
			foreach (ref fl; con.flow) {
				if (fl.from == from) {
					fl.from = to;
				}
			}
		}

		foreach (con; incoming) {
			foreach (ref fl; con.flow) {
				if (fl.to == from) {
					fl.to = to;
				}
			}
		}
		
		foreach (ref con; inputs) {
			if (con.name == from) {
				con.name = to;
			}
		}

		foreach (ref con; outputs) {
			if (con.name == from) {
				con.name = to;
			}
		}
	}
	
	
	void removeOutgoingConnectionsFrom(char[] name) {
		for (int i = 0; i < outgoing.length;) {
			auto con = outgoing[i];
			for (int j = 0; j < con.flow.length;) {
				auto fl = &con.flow[j];
				if (fl.from == name) {
					*fl = con.flow[$-1];
					con.flow = con.flow[0..$-1];
				} else {
					++j;
				}
			}
			if (0 == con.flow.length) {
				con.unlink;
			} else {
				++i;
			}
		}
	}
	
	
	bool removeIncomingConnectionsTo(char[] name) {
		bool res = false;
		
		for (int i = 0; i < incoming.length;) {
			auto con = incoming[i];
			for (int j = 0; j < con.flow.length;) {
				auto fl = &con.flow[j];
				if (fl.to == name) {
					*fl = con.flow[$-1];
					con.flow = con.flow[0..$-1];
					res = true;
				} else {
					++j;
				}
			}
			if (0 == con.flow.length) {
				con.unlink;
				res = true;
			} else {
				++i;
			}
		}

		return res;
	}
	
	
	void onDeleteParam(char[] name) {
		final i = data.params.indexOf(name);
		xf.utils.Array.removeKeepOrder(paramValueInfo, i);
		
		data.params.remove(name);
		removeOutgoingConnectionsFrom(name);
		removeIncomingConnectionsTo(name);
		
		foreach (ref con; inputs) {
			if (con.name == name) {
				con = inputs[$-1];
				inputs = inputs[0..$-1];
				break;
			}
		}
		foreach (ref con; outputs) {
			if (con.name == name) {
				con = outputs[$-1];
				outputs = outputs[0..$-1];
				break;
			}
		}
		
		foreach (con; outgoing) {
			foreach (fl; con.flow) {
				auto src = con.from.outputs.find(fl.from);
				assert (src !is null);
			}
		}
	}
	
	
	void unlink() {
		while (incoming.length) {
			incoming[0].unlink;
		}
		while (outgoing.length) {
			outgoing[0].unlink;
		}
		// TODO: other cleanup (connectors)
	}
	
	
	char[] kernelName() {
		return _kernelName;
	}

	
	class DataCommons {
		ParamList params;
	}
	

	EventHandling clickHandler(ClickEvent e) {
		if (/+MouseButton.Left == e.button && +/e.bubbling && !e.handled) {
			_mngr.onNodeSelected(this);
		}
		
		return EventHandling.Continue;
	}
	
	
	// returns the first one
	Connection hasConnectionToInput(char[] name, char[]* fromOutput = null) {
		foreach (input; incoming) {
			foreach (fl; input.flow) {
				if (fl.to == name) {
					if (fromOutput !is null) {
						*fromOutput = fl.from;
					}
					return input;
				}
			}
		}
		
		return null;
	}


	public {
		bool			showContents = true;
		bool			showDataNames = true;
		NodeContents	contents;
		DataCommons		data;

		ParamValueInfo[]	paramValueInfo;
		
		Connection[]	incoming;
		Connection[]	outgoing;
		
		ConnectorInfo[]	inputs;
		ConnectorInfo[]	outputs;
		
		vec2			spawnPosition = vec2.zero;
		vec2			currentCenter = vec2.zero;
		vec2			currentSize = vec2.zero;

		bool			_isInline;

		// TODO: reload these on kdef refresh
		static assert (false);
		KernelDef		_inlineKernel;
		GraphDef		_inlineGraph;
		
		Type			type;
		char[]			label;
	}
	
	private {
		uint			_id;
		char[]			_kernelName;
		bool			_editingProps;
		GraphMngr		_mngr;
		GraphNodeBox	_widget;

		ScratchFIFO		_mem;

		static uint		g_nextId = 0;
	}
}


class DataConnector : CustomWidget {
	//bool		_dragHandlerRegistered = false;
	mixin	MWidget;
	
	EventHandling delegate(bool input, ConnectorInfo ci, MouseButtonEvent e)
					mouseButtonHandler;
	ConnectorInfo	ci;
	bool			input;
	
	EventHandling handleMouseButton(MouseButtonEvent e) {
		assert (mouseButtonHandler !is null);
		return mouseButtonHandler(input, ci, e);
	}
	
	
	this() {
		addHandler(&handleMouseButton);
	}
}



class GraphMngr {
	/+this(INucleus core) {
		this._core = core;
		this._vfs = core.root;
	}+/
	
	
	void register(Graph graph) {
		_graphs ~= graph;
	}
	

	private {
		GraphNode _prevClicked;
	}
	
	
	GraphNode selected() {
		return _prevClicked;
	}
	
	
	void onNodeSelected(GraphNode node) {
		if (_prevClicked) {
			_prevClicked._widget.disableStyle("selected");
		}
		
		if (node) {
			node._widget.enableStyle("selected");
		}

		_prevClicked = node;
	}
	
	
	public EventHandling handleMouseButton(bool input, ConnectorInfo ci, MouseButtonEvent e) {
		if (MouseButton.Left == e.button && e.down && (e.bubbling && !e.handled)) {
			Stdout.formatln("drag start");
			_connecting = true;
			_connectingFrom = ci;
			_connectingFromInput = input;
			
			gui.addGlobalHandler(&this.globalHandleMouseButton);
			
			if (e.bubbling) {
				return EventHandling.Stop;
			}
		}
		
		return EventHandling.Continue;
	}


	protected bool globalHandleMouseButton(MouseButtonEvent e) {
		if (MouseButton.Left == e.button && !e.down) {
			Stdout.formatln("drag end");
			tryCreateConnection();
			_connecting = false;
			return true;
		}
		
		return false;
	}
	
	
	ConnectorInfo findConnector(vec2 pos, bool inputs, bool outputs, bool autoFlow, GraphNode skipNode, float radius = 20.f) {
		if (autoFlow) {
			radius = 300.f;
		}
		
		float					bestDist = float.max;
		ConnectorInfo	bestCon;
		float					radSq = radius * radius;
		
		foreach (graph; _graphs) {
			foreach (node; graph.nodes) {
				if (node is skipNode) {
					continue;
				}
				
				void process(ConnectorInfo con) {
					float distSq = (con.windowPos - pos).sqLength;
					if (distSq < radSq && distSq < bestDist) {
						bestDist = distSq;
						bestCon = con;
					}
				}
				
				if (inputs) foreach (ref x; node.inputs) {
					if (!autoFlow || x.name == depInputConnectorName) {
						process(x);
					}
				}
				if (outputs) foreach (ref x; node.outputs) {
					if (!autoFlow || x.name == depOutputConnectorName) {
						process(x);
					}
				}
			}
		}
		
		return bestCon;
	}
	
	
	void tryCreateConnection() {
		assert (_connecting);
		
		bool tryingAutoFlow =		(_connectingFromInput && depInputConnectorName == _connectingFrom.name) ||
											(!_connectingFromInput && depOutputConnectorName == _connectingFrom.name);
		
		auto droppedOn = findConnector(mousePos, !_connectingFromInput, _connectingFromInput, tryingAutoFlow, _connectingFrom.node);
		if (!droppedOn) {
			return;
		}
		
		if (_connectingFromInput) {
			if ((depInputConnectorName == _connectingFrom.name) != (droppedOn.name == depOutputConnectorName)) {
				return;
			}
			
			auto flow = DataFlow(droppedOn.name, _connectingFrom.name);
			foreach (con; droppedOn.node.outgoing) {
				if (con.to is _connectingFrom.node) {
					con.flow ~= flow;
					return;
				}
			}
			new Connection(droppedOn.node, _connectingFrom.node, flow);
		} else {
			if ((depOutputConnectorName == _connectingFrom.name) != (droppedOn.name == depInputConnectorName)) {
				return;
			}

			auto flow = DataFlow(_connectingFrom.name, droppedOn.name);
			foreach (con; _connectingFrom.node.outgoing) {
				if (con.to is droppedOn.node) {
					con.flow ~= flow;
					return;
				}
			}
			new Connection(_connectingFrom.node, droppedOn.node, flow);
		}
	}
	
	
	bool connecting() {
		return _connecting;
	}
	
	
	ConnectorInfo connectingFrom() {
		return _connectingFrom;
	}
	
	
	bool connectingFromInput() {
		return _connectingFromInput;
	}
	
	
	vec2 mousePos() {
		return gui.mousePos;
	}
	
	
	Graph[] graphs() {
		return _graphs;
	}
	
	
	VfsFolder vfs() {
		return _vfs;
	}
	
	
	private {
		ConnectorInfo	_connectingFrom;
		bool			_connecting;
		bool			_connectingFromInput;
		Graph[]			_graphs;
		VfsFolder		_vfs;
		//INucleus			_core;
	}
}
