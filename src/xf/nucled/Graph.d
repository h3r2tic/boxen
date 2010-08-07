module xf.nucled.Graph;

private {
	/+import xf.nucleus.CommonDef;
	import xf.nucleus.model.KernelProvider : QuarkRef;
	import xf.nucleus.model.INucleus;
	import xf.nucleus.quark.QuarkDef;
	import xf.nucleus.graph.Node : PrimLevel;
	import xf.nucleus.kdef.Common : KDefGraph = GraphDef, KDefGraphNode = GraphDefNode, ParamListValue;
	import xf.nucleus.kdef.model.IKDefUtilParser;
	import xf.nucleus.KernelImpl : KernelImpl;
	static import xf.nucleus.cpu.Reflection;		// for data inspection+/

	import xf.nucleus.Param;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.kdef.model.IKDefUtilParser;
	import xf.nucleus.kdef.Common : KDefGraph = GraphDef, KDefGraphNode = GraphDefNode, ParamListValue;
	import xf.nucleus.Value;
	
	import xf.hybrid.Hybrid;
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;
	import xf.omg.core.LinearAlgebra;
	import xf.nucled.Widgets;
	import xf.nucled.Misc;
	import xf.nucled.Settings;
	import xf.nucled.DynamicGridInput;
	import xf.utils.Array : arrayRemove = remove;

	import xf.mem.ChunkQueue;
	
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
	
	
	void dump(FormatOutput!(char) p) {
		foreach (n; nodes) {
			n.dump(p);
		}
	
		foreach (n; nodes) {
			foreach (con; n.outgoing) {
				foreach (flow; con.flow) {
					if (depOutputConnectorName == flow.from) {
						p.formatln(`connect node_{} node_{};`\n, con.from.id, con.to.id);
					} else {
						p.formatln(`connect node_{}.{} node_{}.{};`\n, con.from.id, flow.from, con.to.id, flow.to);
					}
				}
			}
		}
	}
	
	
	void load(KDefGraph source) {
		Stdout.formatln("Graph.load() called");
		
		GraphNode[KDefGraphNode]	def2node;
		
		foreach (nname, kdefNode; source.nodes) {
			auto node = new GraphNode(kdefNode);
			def2node[kdefNode] = node;
			node.label = nname;
			addNode(node);
			Stdout.formatln("loading a graph node");
		}
		
		foreach (ncon; source.nodeConnections) {
			new Connection(
				def2node[ncon.from],
				def2node[ncon.to],
				DataFlow(depOutputConnectorName, depInputConnectorName)
			);
		}
		
		foreach (nfcon; source.nodeFieldConnections) {
			new Connection(
				def2node[nfcon.fromNode],
				def2node[nfcon.toNode],
				DataFlow(nfcon.from, nfcon.to)
			);
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
	char[]			name;
	GraphNode	node;
	vec2				windowPos = vec2.zero;
	
	
	this(char[] name, GraphNode node) {
		this.name = name;
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
			this.inputs ~= new ConnectorInfo(depInputConnectorName, this);
		}
		
		if (type != Type.Output) {
			this.outputs ~= new ConnectorInfo(depOutputConnectorName, this);
		}
	}
	

	this(Type t, char[] kernelName) {
		this(t);
		this._kernelName = kernelName;
	}
	
	
	this (KDefGraphNode cfg) {
		_mem.initialize();

		char[] identVal(char[] name) {
			return cfg.getVar(name).as!(IdentifierValue).value;
		}

		this(typeFromString(identVal("type")));
		
		if (auto sp = cfg.getVar("center")) {
			this.spawnPosition = vec2.from(sp.as!(Vector2Value).value);
		}
		
		// there's also the size, but we'll ignore it for now
		
		if (this.isKernelBased) {
			this._kernelName = identVal("kernel");
		} else {
			foreach (param; cfg.params) {
				this.data.params.add(param);
				char[] name = param.name;
				
				if (Type.Output == this.type) {
					inputs ~= new ConnectorInfo(name, this);
				} else {
					outputs ~= new ConnectorInfo(name, this);
				}
			}
		}
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
	
	
	void dump(FormatOutput!(char) p) {
		p.formatln(`node_{} = node {{`, id);
			p.formatln(\t`type = {};`, this.typeName);
			
			if (this.isKernelBased) {
				p.formatln(\t`kernel = {};`, this.kernelName);
			} else {
				if (data.params.length > 0) {
					p(\t`params = (`\n);
					int i = 0;
					foreach (ref param; data.params) {
						p.format(\t\t`{}`, param.toString);

						if (++i != data.params.length) {
							p(",\n");
						} else {
							p("\n");
						}
					}
					p(\t`);`\n);
				}
			}
			
			if (this.spawnPosition.ok) {
				p.formatln(\t`center = {} {};`, this.spawnPosition.x, this.spawnPosition.y);
			}
			
			if (this.currentSize.ok) {
				p.formatln(\t`size = {} {};`, this.currentSize.x, this.currentSize.y);
			}
			
			//p.formatln(\t`primLevel = "{}";`, this.primLevelStr);
		p(`};`\n);
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
				auto con = DataConnector();
				con.layoutAttribs("vexpand");
				if (showDataNames) {
					Label().text(data.name).fontSize(10).valign(1).layoutAttribs("vexpand vfill");
					auto brk = ConnectionBreaker();
					brk.layoutAttribs("vexpand");
					if (brk.clicked) {
						inputToRemove = i;
					}
				}
				con.input = true;
				con.ci = data;
				con.mouseButtonHandler = &_mngr.handleMouseButton;
				data.windowPos = con.globalOffset + con.size * 0.5f;
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
			removeIncomingConnectionsTo(inputs[inputToRemove].name);
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

		if (Type.Calc == this.type || Type.GPUWrap == this.type || Type.Demux == this.type) {
			box.open(`bottom2`);
			//QuarkDef q;
			Label implInfo = Label().fontSize(9);
			
			/+if (quark.isValid && (q = quark.tryGetQuark) !is null) {
				implInfo.text = q.name;
			} else {
				if (isTemplate) {
					implInfo.text = "<template>";
				} else {
					implInfo.text = "<no impl>";
				}
			}+/
			
			
			/+HBox() [{
				Label().text = "Zomg: ";
				
				auto zomg = Combo();
				if (!zomg.initialized) {
					zomg.addItem("Foo");
					zomg.addItem("Bar");
					zomg.addItem("Baz");
				}
			}];
			
			
			HBox() [{
				Label().text = "Lololol: ";
				
				auto zomg = Combo();
				if (!zomg.initialized) {
					zomg.addItem("Foo");
					zomg.addItem("Bar");
					zomg.addItem("Baz");
				}
			}];+/

			
			gui.close;
		}
		
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
	
	
	bool		_choosingImpl;
	//QuarkDef	_quarkBeingEdited;
	
	void doEditorGUI(bool justOpened, bool closing) {
		if (isKernelBased) {
			/+if (justOpened) {
				_choosingImpl = true;
			}
			
			if (_choosingImpl) {
				auto impls = _mngr._core.matcher.getKernelImpl(_kernelName);
				
				void onSelected(KernelImpl impl) {
					if (impl.Type.Direct == impl.type) {
						_choosingImpl = false;
						_quarkBeingEdited = impl.quark;
					} else {
						Label().text = "TODO";
					}
				}

				if (1 == impls.length) {
					onSelected(impls[0]);
				} else if (impls.length > 1) {
					VBox().cfg(`layout={padding = 5 5;}`) [{
						Label().text("Select implementation:");
						Dummy().userSize = vec2(0, 10);
						
						{
							int i = 0;
							auto picker = Picker(); picker [{
								foreach (impl; impls) {
									auto label = Label(i++);
									if (impl.Type.Direct == impl.type) {
										label.text = Format("(direct) {} @ {}", impl.quark.name, impl.detail);
									} else {
										assert (impl.Type.Composite == impl.type);
										label.text = Format("(direct) {} @ {}", impl.graph.label, impl.detail);
									}
								}
							}];
							if (picker.anythingPicked) {
								int j = 0;
								foreach (impl; impls) {
									if (j++ == picker.pickedIdx) {
										onSelected(impl);
									}
								}
								/+foreach (kernel, graph; &core.iterCompositeKernels) {
									if (tabDesc.kernelDef.name == kernel.name) {
										if (j++ == picker.pickedIdx) {
											tabDesc.compositeName = trim(graph.label).dup;
											tabDesc.label = tabDesc.kernelDef.name ~ "( " ~ tabDesc.compositeName ~ " )";
											tabDesc.graphEditor = new GraphEditor(tabDesc.kernelDef.name, core, new GraphMngr(core.root));

											auto path = getCompositeKernelPath(tabDesc.kernelDef.name, tabDesc.compositeName, false);
											KDefGraph graphDef = loadKDefGraph(path);
											tabDesc.graphEditor.loadKernelGraph(graphDef);

											tabDesc.role = TabDesc.Role.GraphEditor;
											break;
										}
									}
								}+/
							}
							
							/+if (0 == i) {
								Label().text("No composite kernels defined");
							}+/
						}
					}];
				}
			}
			
			if (_quarkBeingEdited !is null) {
				doCodeEditorGUI(_quarkBeingEdited, justOpened, closing);
			}
			/+if (quark.isValid && quark.tryGetQuark !is null) {
				
			} else {
				padded(10) = {
					Label().text("You must compile the graph to edit quarks");
				};
			}+/+/
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
		/+void editorSaveHandler() {
			auto sourceVfsFile = _outer.getVfsFile(quark);

			int from, to;
			char[] text;
			{
				auto sourceFile = sourceVfsFile.input;
				scope (exit) sourceFile.close;
				text = cast(char[])sourceFile.load();
				quark.findSourceRange(text, from, to);
			}
			
			static bool startswith(char[] a, char[] b) { return a.length >= b.length && a[0..b.length] == b; }
			static bool endswith(char[] a, char[] b) { return a.length >= b.length && a[$-b.length..$] == b; }
			
			// just a crude check
			if (	text[from..$].startswith(quark.tokenRange.first.value) &&
					text[0..to].endswith(quark.tokenRange.last.value)
			) {
				try {
					if (sourceVfsFile.exists) {
						sourceVfsFile.remove;
					}
				} catch {}		// we don't want failz here. better try to write the contents anyway when shit hits the fan

				try {
					sourceVfsFile.create;
				} catch {}		// ditto

				auto sourceFile = sourceVfsFile.output;
				scope (exit) sourceFile.flush.close;
				sourceFile.write(text[0..from] ~ this.text ~ text[to..$]);
			} else {
				throw new Exception("The file has been modified externally :(");
			}
		}+/

		override protected EventHandling handleKey(KeyboardEvent e) {
			/+if (KeySym.s == e.keySym && (e.modifiers & e.modifiers.CTRL) != 0) {
				if (e.sinking && e.down) {
					this.editorSaveHandler();
				}
				return EventHandling.Stop;
			} else {+/
				return super.handleKey(e);
			//}
		}
		
		//QuarkDef quark;
		GraphNode _outer;
		mixin MWidget;
	}
	
	
	/+VfsFile getVfsFile(QuarkDef quark) {
		auto r = quark.tokenRange;
		auto sourceVfsFile = _mngr.vfs.file(r.first.filename);
		Stdout.formatln("quark file: {} [ {} ]", sourceVfsFile.name, sourceVfsFile.toString);
		return sourceVfsFile;
	}
	
	
	void doCodeEditorGUI(QuarkDef quark, bool justOpened, bool closing) {
		assert (quark !is null);
		
		auto sci = QuarkSciEditor();
		sci.quark = quark;
		sci._outer = this;
		
		if (justOpened) {
			auto sourceVfsFile = getVfsFile(quark);
			auto sourceFile = sourceVfsFile.input;
			scope (exit) sourceFile.close;
			
			int from, to;
			char[] text = cast(char[])sourceFile.load();
			quark.findSourceRange(text, from, to);
			sci.text = text[from..to];

			sci.grabKeyboardFocus();
		}
		
		sci.userSize = vec2(400, 300);
	}+/
	
	
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
				inputs ~= new ConnectorInfo(newName, this);
				auto p = data.params.add(ParamDirection.In, newName);
				p.hasPlainSemantic = true;
				p.type = "void";
			} else {
				outputs ~= new ConnectorInfo(newName, this);
				auto p = data.params.add(ParamDirection.Out, newName);
				p.hasPlainSemantic = true;
				p.type = "void";
			}
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
	
	
	void removeIncomingConnectionsTo(char[] name) {
		for (int i = 0; i < incoming.length;) {
			auto con = incoming[i];
			for (int j = 0; j < con.flow.length;) {
				auto fl = &con.flow[j];
				if (fl.to == name) {
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
	
	
	void onDeleteParam(char[] name) {
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
		
		Connection[]	incoming;
		Connection[]	outgoing;
		
		ConnectorInfo[]	inputs;
		ConnectorInfo[]	outputs;
		
		vec2			spawnPosition = vec2.zero;
		vec2			currentCenter = vec2.zero;
		vec2			currentSize = vec2.zero;
		
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
	
	bool					input;
	ConnectorInfo	ci;
	EventHandling delegate(bool input, ConnectorInfo ci, MouseButtonEvent e) mouseButtonHandler;
	
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
		bool					_connecting;
		bool					_connectingFromInput;
		Graph[]				_graphs;
		VfsFolder			_vfs;
		//INucleus			_core;
	}
}
