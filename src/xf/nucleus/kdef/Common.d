module xf.nucleus.kdef.Common;

private {
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

	import TextUtil = tango.text.Util;
	alias char[] string;

	import xf.nucleus.Log : log = nucleusLog;
}




abstract class Scope {
	Statement[]	statements;

	// after semantic analysis:
	
	Value[string]	vars;
	
	
	private final Scope getValueOwner(string name, string* finalName) {
		int dotPos = TextUtil.locate(name, '.');
		if (dotPos < name.length) {
			string prefix = name[0..dotPos];
			string suffix = name[dotPos+1..$];
			if (0 == prefix.length || 0 == suffix.length) {
				throw new Exception("invalid field name: '" ~ name ~ ".");
			}
			
			if (auto prefixVal = prefix in vars) {
				if (auto scopeVal = cast(IScopeValue)*prefixVal) {
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
	
	
	final void doAssign(string name, Value value) {
		string finalName;
		auto sc = getValueOwner(name, &finalName);
		sc.doAssignSelf(finalName, value);
	}
	

	void doAssignSelf(string name, Value value) {
		vars[name] = value;
	}


	void doImport(void delegate(void delegate(Statement)) stProducer) {
		stProducer((Statement st) {
			importStatement(st);
		});
	}
	
	abstract void importStatement(Statement st);
}


class TraitDef {
	string	name;
	string[]	values;
	string	defaultValue;
}


class KDefModule : Scope {
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


class GraphDef : Scope, IGraphDef {
	string		superKernel;
	string[]	tags;
	
	this (Statement[] statements) {
		this.statements = statements;
	}

	static GraphDef opCall(IGraphDef i) {
		final res = cast(GraphDef)i;
		assert (res !is null);
		return res;
	}
	

	override void doAssignSelf(string name, Value value) {
		super.doAssignSelf(name, value);
		
		if (auto nodeValue = cast(GraphDefNodeValue)value) {
			nodes[name] = nodeValue.node;
			
			if (name in graphs) {
				graphs.remove(name);
			}
		} else if (auto graphValue = cast(GraphDefValue)value) {
			graphs[name] = graphValue.graphDef;
			if (name in nodes) {
				nodes.remove(name);
			}
		} else {
			throw new Exception("graphs can only contain nodes and graphs, not '" ~ name ~ "' " ~ value.classinfo.name);
		}
	}

	
	// after semantic analysis:

	string					_name;
	GraphDefNode[string]	nodes;
	GraphDef[string]		graphs;
	NodeConnection[]		nodeConnections;
	NodeFieldConnection[]	nodeFieldConnections;
	
	struct NodeConnection {
		GraphDefNode from, to;
	}
	
	struct NodeFieldConnection {
		GraphDefNode fromNode, toNode;
		string from, to;
	}
	
	override void importStatement(Statement st) {
		// TODO
	}


	// For the silly interface
	char[] name() {
		return _name;
	}

	size_t numNodes() {
		return nodes.length;
	}
	
	
	void doConnect(string from_, string to_) {
		string fromName;
		auto fromScope = getValueOwner(from_, &fromName);
		string toName;
		auto toScope = getValueOwner(to_, &toName);
		
		if (auto fromGraph = cast(GraphDef)fromScope) {
			if (auto toGraph = cast(GraphDef)toScope) {
				if (auto fromNode = fromName in fromGraph.nodes) {
					if (auto toNode = toName in toGraph.nodes) {
						nodeConnections ~= NodeConnection(*fromNode, *toNode);
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


class GraphDefNode : Scope {
	this (VarDef[] vars_) {
		foreach (var; vars_) {
			this.vars[var.name] = var.value;
		}
	}

	char[] type() {
		auto typeVar = vars["type"];
		assert (cast(IdentifierValue)typeVar);
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


interface IScopeValue {
	Scope toScope();
}


class KernelDefValue : Value {
	KernelDef kernelDef;
}


class GraphDefValue : Value, IScopeValue {
	GraphDef graphDef;
	
	// implements IScopeValue
	Scope toScope() {
		return graphDef;
	}
}


class GraphDefNodeValue : Value, IScopeValue {
	GraphDefNode node;
	
	// implements IScopeValue
	override Scope toScope() {
		assert (node !is null);
		return node;
	}
}


class SurfaceDefValue : Value {
	SurfaceDef surface;
}


class MaterialDefValue : Value {
	MaterialDef material;
}

class SamplerDefValue : Value {
	SamplerDef value;
}


class TraitDefValue : Value {
	TraitDef value;
}


class ParamListValue : Value {
	ParamDef[] value;
	
	this (ParamDef[] params) {
		assert (params.length > 0);
		this.value = params.dup;
		//log.info("ParamListValue @ {:x} has {} params", cast(void*)this, params.length);
	}
}


abstract class Statement {
}


class ConnectStatement : Statement {
	string from;
	string to;
	
	this (string from, string to) {
		this.from = from.dup;
		this.to = to.dup;
	}
}


class AssignStatement : Statement {
	string name;
	Value value;
	
	this (string name, Value value) {
		this.name = name.dup;
		this.value = value;
	}
}


class ImportStatement : Statement {
	string path;
	string[] what;
	
	this (string path, string[] what) {
		this.path = path;
		this.what = what;
	}
}


class ConverterDeclStatement : Statement {
	Function	func;
	int			cost;
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
}
