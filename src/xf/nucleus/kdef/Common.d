module xf.nucleus.kdef.Common;

private {
	import xf.nucleus.Defs;
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.Code;
	import xf.nucleus.Function;
	import xf.nucleus.TypeConversion;
	
	import xf.nucleus.kernel.KernelDef;
	import xf.nucleus.kernel.KernelImplDef;
	import xf.nucleus.quark.QuarkDef;

	import TextUtil = tango.text.Util;
	alias char[] string;
}



// TODO: could be optimized
string[] dupStringArray(string[] arr) {
	string[] res = new string[arr.length];
	foreach (i, s; arr) {
		res[i] = s.dup;
	}
	return res;
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
	bool		processing;
	
	// after semantic analysis:
	ImplementStatement[]	kernelImpls;
	KernelDef[]				kernels;
	TraitDef[]				traitDefs;
	SemanticConverter[]		converters;
	
	
	override void importStatement(Statement st) {
		// TODO
	}
}


abstract class KernelImplementation : Value {
	void doSemantics(void delegate(Scope) dg) {
		// nothing
	}
}


class QuarkDefValue : KernelImplementation {
	/+Code[]		code;
	Function[]	functions;
	
	this (Code[] code, Function[] functions) {
		this.code = code;
		this.functions = functions;
	}+/
	
	
	QuarkDef	quarkDef;
	
	
	this (char[] name, Code[] code, Function[] functions) {
		quarkDef = new QuarkDef;
		quarkDef.name = name.dup;
		quarkDef.code = code;
		quarkDef.functions = functions;
	}
}


class GraphDef : Scope {
	string label;
	
	this (Statement[] statements) {
		this.statements = statements;
	}
	

	override void doAssignSelf(string name, Value value) {
		super.doAssignSelf(name, value);
		
		if (auto nodeValue = cast(GraphDefNodeValue)value) {
			nodes[name] = nodeValue.node;
			nodeValue.node.label = name;
			
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
	
	KernelImplDef[]				implList;
	GraphDefNode[string]	nodes;
	GraphDef[string]			graphs;
	NodeConnection[]			nodeConnections;
	NodeFieldConnection[]	nodeFieldConnections;
	PreprocessCmd[]			preprocessCmds;
	
	struct NodeConnection {
		GraphDefNode from, to;
	}
	
	struct NodeFieldConnection {
		GraphDefNode fromNode, toNode;
		string from, to;
	}
	
	struct PreprocessCmd {
		string	processor;
		string	processorFunction;
	}


	override void importStatement(Statement st) {
		// TODO
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
	string label;
	
	
	this (VarDef[] vars_) {
		foreach (var; vars_) {
			this.vars[var.name] = var.value;
		}
	}


	override void importStatement(Statement st) {
		// TODO
	}
}


interface IScopeValue {
	Scope toScope();
}


class GraphDefValue : KernelImplementation, IScopeValue {
	GraphDef	graphDef;


	override void doSemantics(void delegate(Scope) dg) {
		dg(graphDef);
	}

	
	this (GraphDef graphDef, string label) {
//		Stdout.formatln("GraphDefValue('{}')", label);
		this.graphDef = graphDef;
		this.graphDef.label = label is null ? null : label.dup;
	}
	
	
	// implements IScopeValue
	Scope toScope() {
		return graphDef;
	}
}


class GraphDefNodeValue : Value, IScopeValue {
	GraphDefNode	node;
	
	this (GraphDefNode node) {
		this.node = node;
	}
	
	
	// implements IScopeValue
	override Scope toScope() {
		assert (node !is null);
		return node;
	}
}


class KernelDefValue : Value {
	KernelDef kernelDef;
	
	this (string domain, KernelDef kernelDef, string[] bases) {
		this.kernelDef = kernelDef;
		
		switch (domain) {
			case "cpu": {
				kernelDef.domain = Domain.CPU;
			} break;

			case "gpu": {
				kernelDef.domain = Domain.GPU;
			} break;
			
			case "any": {
				kernelDef.domain = Domain.Any;
			} break;
			
			default: {
				throw new Exception("'"~domain~"' is not a valid kernel domain name");
			}
		}
		
		kernelDef.overrideInheritList(bases.dupStringArray());
	}
}


class TraitDefValue : Value {
	TraitDef value;
	
	this (string[] values, string defaultValue) {
		value = new TraitDef;
		value.values = values.dupStringArray();
		value.defaultValue = defaultValue.dup;
	}
}


class ParamListValue : Value {
	Param[] value;
	
	this (Param[] params) {
		this.value = params;
	}
}


abstract class Statement {
}


class ImplementStatement : Statement {
	KernelImplDef[] impls;
	KernelImplementation impl;
	
	this (KernelImplDef[] impls, KernelImplementation impl) {
		this.impls = impls;
		this.impl = impl;
	}
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
		this.path = path.dup;
		this.what = what.dupStringArray();
	}
}


class ConverterDeclStatement : Statement {
	Param[] params;
	Code code;
	string name;
	
	this (Param[] params, Code code, string name) {
		this.params = params;
		this.code = code;
		this.name = name;
	}
}


class PreprocessStatement : Statement {
	string processor;
	string processorFunction;
	
	this (string processor, string processorFunction) {
		this.processor = processor;
		this.processorFunction = processorFunction;
	}
}


class ParamSemantic {
	VarDef[]		annotations;
	Value[string]	traits;
}
