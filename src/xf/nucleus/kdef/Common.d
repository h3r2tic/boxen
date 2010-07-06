module xf.nucleus.kdef.Common;

private {
	import xf.Common : equal, DgAllocator;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.Code;
	import xf.nucleus.Function;
	import xf.nucleus.TypeConversion;
	import xf.nucleus.KernelImpl;
	import xf.nucleus.SurfaceDef;
	import xf.nucleus.MaterialDef;
	import xf.nucleus.SamplerDef;
	
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.graph.GraphDef;

	import xf.nucleus.DepTracker;

	import xf.mem.ChunkQueue;		// for ScratchFIFO
	import xf.mem.ScratchAllocator;

	import TextUtil = tango.text.Util;
	alias char[] string;

	import xf.nucleus.Log : log = nucleusLog, error = nucleusError;
}




abstract class Scope {
	Statement[]			statements;
	DgScratchAllocator	mem;

	// after semantic analysis:

	private {
		string[]	_varNames;
		Value[]		_varValues;
	}

	this(DgAllocator allocator) {
		mem = DgScratchAllocator(allocator);
	}

	protected void setVars(VarDef[] vars) {
		assert (_varNames is null);
		_varNames = mem.allocArrayNoInit!(string)(vars.length);
		_varValues = mem.allocArrayNoInit!(Value)(vars.length);
		foreach (i, v; vars) {
			_varNames[i] = v.name;
			_varValues[i] = v.value;
		}
	}

	Value getVar(string name) {
		foreach (i, n; _varNames) {
			if (n == name) {
				return _varValues[i];
			}
		}
		return null;
	}
	
	
	private final Scope getValueOwner(string name, string* finalName) {
		int dotPos = TextUtil.locate(name, '.');
		if (dotPos < name.length) {
			string prefix = name[0..dotPos];
			string suffix = name[dotPos+1..$];
			if (0 == prefix.length || 0 == suffix.length) {
				throw new Exception("invalid field name: '" ~ name ~ ".");
			}
			
			if (auto prefixVal = getVar(prefix)) {
				if (auto scopeVal = cast(IScopeValue)prefixVal) {
					auto sc = scopeVal.toScope();
					assert (sc !is null);
					return sc.getValueOwner(suffix, finalName);
				} else {
					throw new Exception(prefixVal.classinfo.name ~ " is not a valid scope");
				}
			} else {
				// TODO: better error msg
				throw new Exception("no variable '" ~ prefix ~ "' in scope " ~ this.classinfo.name);
			}
		} else {
			*finalName = name;
			return this;
		}
	}
	

	// assumes ownership of the arrays
	void doAssign(string[] names, Value[] values) {
		assert (_varNames is null);
		assert (_varValues is null);

		foreach (ref n; names) {
			string finalName;
			auto sc = getValueOwner(n, &finalName);
			n = finalName;
		}

		_varNames = names;
		_varValues = values;
	}
	

	// NOTE: Only valid after semantic analysis
	bool opEquals(Scope other) {
		if (
				_varNames.length != other._varNames.length
			||	statements.length != other.statements.length
		) {
			return false;
		}

		foreach (vi, vn; _varNames) {
			auto vv = _varValues[vi];
			if (other._varNames[vi] != vn || !equal(other._varValues[vi], vv)) {
				return false;
			}
		}

		foreach (i, s; statements) {
			if (!s.opEquals(other.statements[i])) {
				return false;
			}
		}

		return true;
	}


	void doImport(void delegate(void delegate(Statement)) stProducer) {
		stProducer((Statement st) {
			importStatement(st);
		});
	}
	
	abstract void importStatement(Statement st);
}


class TraitDef {
	string		name;
	string[]	values;
	string		defaultValue;

	bool opEquals(TraitDef other) {
		// TODO: is the string[] comparison comparing string contents or pointers?
		return name == other.name && values == other.values && defaultValue == other.defaultValue;
	}
}


class KDefModule : Scope {
	ScratchFIFO	scratchFIFO;

	this () {
		scratchFIFO.initialize();
		super(&scratchFIFO.pushBack);
	}

	~this() {
		scratchFIFO.clear();
	}
	
	string	filePath;
	bool	processing;
	
	// after semantic analysis:
	KernelImpl[string]		kernels;
	SurfaceDef[string]		surfaces;
	MaterialDef[string]		materials;

	TraitDef[]				traitDefs;

	SemanticConverter[]		converters;
	
	
	override void importStatement(Statement st) {
		// TODO
	}
}


final class GraphDefNode : Scope {
	this (VarDef[] vars_, DgAllocator allocator) {
		super(allocator);
		this.setVars(vars_);
	}

	char[] type() {
		auto typeVar = getVar("type");
		assert (cast(IdentifierValue)typeVar, "type fields for graph nodes must be idents");
		return (cast(IdentifierValue)typeVar).value;
	}

	override void importStatement(Statement st) {
		// TODO
	}

	// after semantics for kernel nodes

	KernelImpl	kernelImpl;

	// after semantics for param nodes

	ParamList	params;
}


final class GraphDef : Scope, IGraphDef {
	string		superKernel;
	DepTracker	_dependentOnThis;

	this (Statement[] statements, DgAllocator allocator) {
		super (allocator);
		this.statements = statements;
		_dependentOnThis = DepTracker(allocator);
	}


	static GraphDef opCall(IGraphDef i) {
		final res = cast(GraphDef)i;
		assert (res !is null);
		return res;
	}


	DepTracker* dependentOnThis() {
		return &_dependentOnThis;
	}


	bool opEquals(IGraphDef other) {
		return opEquals(GraphDef(other));
	}


	private struct NodeFruct {
		GraphDef _this;
		int opApply(int delegate(ref string, ref GraphDefNode) sink) {
			return _this._iterNodes(sink);
		}
		size_t length() {
			return _this._nodes.length;
		}
	}

	NodeFruct nodes() {
		return NodeFruct(this);
	}
	private int _iterNodes(int delegate(ref string, ref GraphDefNode) sink) {
		foreach (i, ref nn; _nodeNames) {
			if (int r = sink(nn, _nodes[i])) {
				return r;
			}
		}
		return 0;
	}
	

	bool opEquals(GraphDef other) {
		if (	_name != other._name
			||	superKernel != other.superKernel
			||	_nodes.length != other._nodes.length
			||	nodeConnections.length != other.nodeConnections.length
			||	nodeFieldConnections.length != other.nodeFieldConnections.length
		) {
			if (_name != other._name) log.info("blah1");
			if (superKernel != other.superKernel) log.info("blah2");
			if (_nodes.length != other._nodes.length) log.info("blah3");
			if (nodeConnections.length != other.nodeConnections.length) log.info("blah4");
			if (nodeFieldConnections.length != other.nodeFieldConnections.length) log.info("blah5");
			log.info("blah");
			return false;
		}

		return super.opEquals(other);
	}
	

	void invalidateIfDifferent(GraphDef other) {
		if (!opEquals(other)) {
			dependentOnThis().valid = false;
		}
	}


	override void doAssign(string[] names, Value[] values) {
		super.doAssign(names, values);
		
		size_t num = 0;
		foreach (v; values) {
			if (cast(GraphDefNodeValue)v) {
				++num;
			}
		}

		_nodeNames = mem.allocArrayNoInit!(string)(num);
		_nodes = mem.allocArrayNoInit!(GraphDefNode)(num);

		num = 0;
		foreach (i, v; values) {
			if (auto nodeValue = cast(GraphDefNodeValue)v) {
				_nodeNames[num] = names[i];
				_nodes[num] = nodeValue.node;
				++num;
			}
		}
	}

	
	// after semantic analysis:

	string					_name;
	string[]				_nodeNames;
	GraphDefNode[]			_nodes;
	NodeConnection[]		nodeConnections;
	NodeFieldConnection[]	nodeFieldConnections;
	
	struct NodeConnection {
		GraphDefNode from, to;
	}
	
	struct NodeFieldConnection {
		GraphDefNode fromNode, toNode;
		string from, to;
	}
	
	GraphDefNode getNode(string name) {
		foreach (i, n; _nodeNames) {
			if (n == name) {
				return _nodes[i];
			}
		}
		return null;
	}

	override void importStatement(Statement st) {
		// TODO
	}


	// For the silly interface
	char[] name() {
		return _name;
	}

	size_t numNodes() {
		return _nodes.length;
	}
	
	
	void doConnect(string from_, string to_) {
		string fromName;
		auto fromScope = getValueOwner(from_, &fromName);
		string toName;
		auto toScope = getValueOwner(to_, &toName);
		
		if (auto fromGraph = cast(GraphDef)fromScope) {
			if (auto toGraph = cast(GraphDef)toScope) {
				if (auto fromNode = fromGraph.getNode(fromName)) {
					if (auto toNode = toGraph.getNode(toName)) {
						nodeConnections ~= NodeConnection(fromNode, toNode);
					} else {
						throw new Exception("no target node");
					}
				} else {
					throw new Exception("no source node");
				}
			} else {
				throw new Exception("can't connect a node to a field");
			}
		} else if (auto fromNode = cast(GraphDefNode)fromScope) {
			if (auto toNode = cast(GraphDefNode)toScope) {
				nodeFieldConnections ~= NodeFieldConnection(
					fromNode, toNode,
					fromName, toName
				);
			} else {
				throw new Exception("can't connect a field to a node");
			}
		} else {
			throw new Exception("Connect a what? oO got: " ~ fromScope.classinfo.name);
		}
	}
}


interface IScopeValue {
	Scope toScope();
}


class KernelDefValue : Value {
	KernelDef kernelDef;

	override bool opEquals(Value other) {
		if (auto o = cast(KernelDefValue)other) {
			return kernelDef == o.kernelDef;
		} else {
			return false;
		}
	}
}


class GraphDefValue : Value, IScopeValue {
	GraphDef graphDef;
	
	override bool opEquals(Value other) {
		if (auto o = cast(GraphDefValue)other) {
			return graphDef == o.graphDef;
		} else {
			return false;
		}
	}

	// implements IScopeValue
	Scope toScope() {
		return graphDef;
	}
}


class GraphDefNodeValue : Value, IScopeValue {
	GraphDefNode node;
	
	override bool opEquals(Value other) {
		if (auto o = cast(GraphDefNodeValue)other) {
			return node == o.node;
		} else {
			return false;
		}
	}

	// implements IScopeValue
	override Scope toScope() {
		assert (node !is null);
		return node;
	}
}


class SurfaceDefValue : Value {
	SurfaceDef surface;

	override bool opEquals(Value other) {
		if (auto o = cast(SurfaceDefValue)other) {
			return surface == o.surface;
		} else {
			return false;
		}
	}
}

class MaterialDefValue : Value {
	MaterialDef material;

	override bool opEquals(Value other) {
		if (auto o = cast(MaterialDefValue)other) {
			return material == o.material;
		} else {
			return false;
		}
	}
}

class SamplerDefValue : Value {
	SamplerDef value;

	override bool opEquals(Value other) {
		if (auto o = cast(SamplerDefValue)other) {
			return value == o.value;
		} else {
			return false;
		}
	}
}


class TraitDefValue : Value {
	TraitDef value;

	override bool opEquals(Value other) {
		if (auto o = cast(TraitDefValue)other) {
			return value == o.value;
		} else {
			return false;
		}
	}
}


class ParamListValue : Value {
	ParamDef[] value;
	
	this (ParamDef[] params) {
		assert (params.length > 0);
		this.value = params;
	}

	override bool opEquals(Value other) {
		if (auto o = cast(ParamListValue)other) {
			if (value.length != o.value.length) {
				return false;
			}
			
			foreach (i, p; value) {
				if (p != o.value[i]) {
					return false;
				}
			}
			return true;
		} else {
			return false;
		}
	}
}


abstract class Statement {
	abstract bool opEquals(Statement other);
}


class ConnectStatement : Statement {
	string from;
	string to;
	
	this (string from, string to) {
		this.from = from;
		this.to = to;
	}

	override bool opEquals(Statement other) {
		if (auto o = cast(ConnectStatement)other) {
			return from == o.from && to == o.to;
		} else {
			return false;
		}
	}
}


class AssignStatement : Statement {
	string name;
	Value value;
	
	this (string name, Value value) {
		this.name = name;
		this.value = value;
	}

	override bool opEquals(Statement other) {
		if (auto o = cast(AssignStatement)other) {
			return name == o.name && value == o.value;
		} else {
			return false;
		}
	}
}


class ImportStatement : Statement {
	string path;
	string[] what;
	
	this (string path, string[] what) {
		this.path = path;
		this.what = what;
	}

	override bool opEquals(Statement other) {
		if (auto o = cast(ImportStatement)other) {
			// TODO: does == for string[] compare contents or ptrs?
			return path == o.path && what == o.what;
		} else {
			return false;
		}
	}
}


class ConverterDeclStatement : Statement {
	Function	func;
	int			cost;

	override bool opEquals(Statement other) {
		if (auto o = cast(ConverterDeclStatement)other) {
			return func == o.func && cost == o.cost;
		} else {
			return false;
		}
	}
}


class ParamSemanticExp {
	enum Type {
		Sum,
		Exclusion,
		Trait
	}

	union {
		struct {
			ParamSemanticExp exp1;
			ParamSemanticExp exp2;
		}
		struct {
			string name;
			string value;
		}
	}

	Type type;


	this (Type t) {
		this.type = t;
	}


	bool opEquals(ParamSemanticExp other) {
		if (type != other.type) {
			return false;
		}
		
		switch (type) {
			case Type.Sum:
			case Type.Exclusion:
				return exp1.opEquals(other.exp1) && exp2.opEquals(other.exp2);
			case Type.Trait:
				return name == other.name && value == other.value;
			default: assert (false);
		}
	}
}


class ParamDef {
	string dir;
	string type;
	ParamSemanticExp paramSemantic;
	string name;
	Value defaultValue;

	this (
			string dir,
			string type,
			ParamSemanticExp paramSemantic,
			string name,
			Value defaultValue
	) {
		this.dir = dir;
		this.type = type;
		this.paramSemantic = paramSemantic;
		this.name = name;
		this.defaultValue = defaultValue;
	}

	bool opEquals(ParamDef other) {
		return
			dir == other.dir
		&&	type == other.type
		&&	equal(paramSemantic, other.paramSemantic)
		&&	name == other.name
		&&	equal(defaultValue, other.defaultValue);
	}
}
