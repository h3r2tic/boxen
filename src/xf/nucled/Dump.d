module xf.nucled.Dump;

private {
	import xf.Common;

	import
		xf.nucleus.Param,
		xf.nucleus.Value,
		xf.nucleus.SamplerDef,
		xf.nucleus.kdef.Common;
	
	import
		xf.nucled.Graph,
		xf.nucled.Settings,
		xf.nucled.ParametersRollout,
		xf.nucled.DataProvider,
		xf.nucled.Log;

	import tango.text.Util;
	import tango.io.stream.Format;
	import tango.text.convert.Layout : TextLayout = Layout;
	import tango.io.device.File : FileConduit = File;
	import tango.io.model.IConduit : InputStream, OutputStream;
	import tango.sys.Process;
}



void dumpGraph(Graph graph, cstring label, OutputStream cond) {
	scope layout = new TextLayout!(char);
	scope print = new FormatOutput!(char)(layout, cond, "\n");
	
	print.formatln(`{} = `, label);
	dumpGraph(graph, print);
	print.flush;
	cond.flush;
}


void dumpGraph(Graph graph, OutputStream cond) {
	scope layout = new TextLayout!(char);
	scope print = new FormatOutput!(char)(layout, cond, "\n");
	
	dumpGraph(graph, print);
	print.flush;
	cond.flush;
}


void dumpMaterial(Graph graph, cstring matName, cstring kernelName, OutputStream cond) {
	scope layout = new TextLayout!(char);
	scope p = new FormatOutput!(char)(layout, cond, "\n");

	p.formatln(`{} = material {} {{`, matName, kernelName);

	foreach (n; graph.nodes) {
		if (GraphNode.Type.Data == n.type) {
			foreach (paramI, ref param; n.data.params) {
				if (param.value && n.paramValueInfo) {
					p.format(\t\t`{}`, param.name);

					ParamValueInfo* pvi;
					if (n.paramValueInfo) {
						pvi = &n.paramValueInfo[paramI];
					}

					dumpParamValueInfo(&param, pvi, p);
					p(';').newline;
				}
			}
		}
	}
	
	p(`};`).newline;
	p.flush;
	cond.flush;
}


private void dumpGraph(Graph graph, FormatOutput!(char) p) {
	p.formatln(`graph {{`);
	
	foreach (n; graph.nodes) {
		dumpGraphNode(n, p);
	}

	foreach (n; graph.nodes) {
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

	p.formatln(`};`);
}


/+private void dumpGraph(GraphDef graph, FormatOutput!(char) p) {
	p.formatln(`graph {} {{`, graph.superKernel);
	
	foreach (nname, n; graph.nodes) {
		dumpGraphNode(nname, n, p);
	}

	cstring nodeName(GraphDefNode n) {
		foreach (nname, nd; graph.nodes) {
			if (nd is n) {
				return nname;
			}
		}
		assert (false);
	}

	foreach (con; graph.nodeConnections) {
		p.formatln(`connect {} {};`\n, nodeName(con.from), nodeName(con.to));
	}

	foreach (con; graph.nodeFieldConnections) {
		p.formatln(`connect {}.{} {}.{};`\n, nodeName(con.fromNode), con.from, nodeName(con.toNode), con.to);
	}

	foreach (naf; graph.noAutoFlow) {
		p.formatln(`noauto {}.{};`\n, nodeName(naf.toNode), naf.to);
	}

	p.formatln(`};`);
}+/


private void dumpGraphNode(GraphNode n, FormatOutput!(char) p) {
	p.formatln(`node_{} = node {{`, n.id);
		p.formatln(\t`type = {};`, n.typeName);
		
		if (n.isKernelBased) {
			if (n._isInline) {
				p(\t`kernel = `);

				KDefModule	mod;
				size_t		start;
				size_t		bytes;
				
				if (n._inlineGraph) {
					mod = cast(KDefModule)n._inlineGraph._module;
					start = n._inlineGraph._firstByte;
					bytes = n._inlineGraph._lengthBytes;
					//dumpGraph(n._inlineGraph, p);
				} else {
					assert (n._inlineKernel);
					mod = cast(KDefModule)n._inlineKernel._module;
					start = n._inlineKernel._firstByte;
					bytes = n._inlineKernel._lengthBytes;
					//dumpKernel(n._inlineKernel, p);
				}

				assert (mod !is null);

				auto input = .xf.nucleus.Nucleus.vfs.file(mod.filePath).input();
				scope(exit) input.close;
				cstring data = cast(cstring)input.load();

				p(data[start..start+bytes]);

				p(`;`);
			} else {
				p.formatln(\t`kernel = {};`, n.kernelName);
			}
		} else {
			if (n.data.params.length > 0) {
				p(\t`params = (`\n);
				int i = 0;
				foreach (paramI, ref param; n.data.params) {
					p.format(\t\t`{}`, param.toString);

					ParamValueInfo* pvi;
					if (n.paramValueInfo) {
						pvi = &n.paramValueInfo[paramI];
					}

					dumpParamValueInfo(&param, pvi, p);

					if (++i != n.data.params.length) {
						p(",\n");
					} else {
						p("\n");
					}
				}
				p(\t`);`\n);
			}
		}
		
		if (n.spawnPosition.ok) {
			p.formatln(\t`center = {} {};`, n.spawnPosition.x, n.spawnPosition.y);
		}
		
		if (n.currentSize.ok) {
			p.formatln(\t`size = {} {};`, n.currentSize.x, n.currentSize.y);
		}
		
		//p.formatln(\t`primLevel = "{}";`, n.primLevelStr);
	p(`};`\n);
}


/+private void dumpKernel(KernelDef k, FormatOutput!(char) p) {
	// TODO
}


private void dumpGraphNode(cstring nname, GraphDefNode n, FormatOutput!(char) p) {
	p.formatln(`{} = node {{`, nname);
		p.formatln(\t`type = {};`, n.type);
		
		if ("kernel" == n.type) {
			// TODO
		} else {
			if (n.params.length > 0) {
				p(\t`params = (`\n);
				int i = 0;
				foreach (paramI, ref param; n.params) {
					p.format(\t\t`{}`, param.toString);

					if (++i != n.params.length) {
						p(",\n");
					} else {
						p("\n");
					}
				}
				p(\t`);`\n);
			}
		}
		
		if (n.spawnPosition.ok) {
			p.formatln(\t`center = {} {};`, n.spawnPosition.x, n.spawnPosition.y);
		}
		
		if (n.currentSize.ok) {
			p.formatln(\t`size = {} {};`, n.currentSize.x, n.currentSize.y);
		}
		
		//p.formatln(\t`primLevel = "{}";`, n.primLevelStr);
	p(`};`\n);
}
+/

private void dumpParamValueInfo(
	Param* param,
	ParamValueInfo* info,
	FormatOutput!(char) p
) {
	assert (param !is null);

	// TODO: proper dumping of annotations

	if (param.value) {
		p(" = ");
		dumpParamValue(param, p);
	}

	if (info && info.provider) {
		p.formatln(" @gui(");
		p.formatln("widget = {};", info.provider.name);
		info.provider.dumpConfig(p);
		p(")");
	} else {
		if (param.annotation) {
			final annots = *cast(Annotation[]*)param.annotation;
			foreach (annot; annots) {
				if ("gui" == annot.name) {
					dumpParamAnnot(annot.name, annot.vars, p);
					break;
				}
			}
		}
	}
}


private void dumpParamAnnot(
	cstring name,
	VarDef[] vars,
	FormatOutput!(char) p
) {
	p.formatln(" @{}(", name);
	foreach (var; vars) {
		p.format("{} = ", var.name);
		dumpValue(var.value, p);
		p(';').newline;
	}
	p(")");
}


private void dumpValue(
	Value val,
	FormatOutput!(char) p
) {
	if (auto v = cast(NumberValue)val) {
		p.format("{}", v.value);
	} else if (auto v = cast(BooleanValue)val) {
		p.format("{}", v.value);
	} else if (auto v = cast(Vector2Value)val) {
		p.format("{} {}", v.value.tuple);
	} else if (auto v = cast(Vector3Value)val) {
		p.format("{} {} {}", v.value.tuple);
	} else if (auto v = cast(Vector4Value)val) {
		p.format("{} {} {} {}", v.value.tuple);
	} else if (auto v = cast(StringValue)val) {
		p.format("\"{}\"", v.value);
	} else if (auto v = cast(IdentifierValue)val) {
		p.format("{}", v.value);
	} else {
		nucledError("Unhandled value type when taking a dump: '{}'.", val.classinfo.name);
	}
}


private void dumpParamValue(
	Param* param,
	FormatOutput!(char) p
) {
	switch (param.valueType) {
		case ParamValueType.Float: {
			float x;
			param.getValue(&x);
			p.format("{}", x);
		} break;
		case ParamValueType.Float2: {
			float x, y;
			param.getValue(&x, &y);
			p.format("{} {}", x, y);
		} break;
		case ParamValueType.Float3: {
			float x, y, z;
			param.getValue(&x, &y, &z);
			p.format("{} {} {}", x, y, z);
		} break;
		case ParamValueType.Float4: {
			float x, y, z, w;
			param.getValue(&x, &y, &z, &w);
			p.format("{} {} {} {}", x, y, z, w);
		} break;
		case ParamValueType.String: {
			cstring val;
			param.getValue(&val);
			p.format("\"{}\"", val);
		} break;
		case ParamValueType.Ident: {
			cstring val;
			param.getValueIdent(&val);
			p.format("{}", val);
		} break;
		case ParamValueType.ObjectRef: {
			Object objVal;
			param.getValue(&objVal);
			if (auto sampler = cast(SamplerDef)objVal) {
				p("sampler {");
				foreach (ref par; sampler.params) {
					p.format("{} = ", par.name);
					dumpParamValue(&par, p);
					p("; ");
				}
				p("}");
				/+mat.info[i].ptr = mem._new!(Texture)();
				Texture* tex = cast(Texture*)mat.info[i].ptr;
				loadMaterialSamplerParam(backend, sampler, tex);+/
			} else {
				error(
					"Don't know what to do with"
					" a {} material param ('{}').",
					objVal.classinfo.name,
					param.name
				);
			}
		} break;
		default: break;
	}
}
