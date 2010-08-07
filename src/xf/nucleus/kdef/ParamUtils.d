module xf.nucleus.kdef.ParamUtils;

private {
	import xf.nucleus.kdef.Common;
	import xf.nucleus.Param;
	import xf.nucleus.Value;
	import xf.nucleus.TypeSystem;
	import xf.nucleus.Log;
	import xf.omg.core.LinearAlgebra;
}



// TODO: verify that the param type matches if it has a type constraint
void setParamValue(Param* p, Value v) {
	if (v is null) {
		p.value = null;
	} else if (auto v = cast(NumberValue)v) {
		p.setValue(cast(float)v.value);
	} else if (auto v = cast(Vector2Value)v) {
		p.setValue(cast(float)v.value.x, cast(float)v.value.y);
	} else if (auto v = cast(Vector3Value)v) {
		p.setValue(cast(float)v.value.x, cast(float)v.value.y, cast(float)v.value.z);
	} else if (auto v = cast(Vector4Value)v) {
		p.setValue(cast(float)v.value.x, cast(float)v.value.y, cast(float)v.value.z, cast(float)v.value.w);
	} else if (auto v = cast(StringValue)v) {
		p.setValue(v.value);
	} else if (auto v = cast(IdentifierValue)v) {
		p.setValueIdent(v.value);
	} else if (auto v = cast(SamplerDefValue)v) {
		// HACK: needs proper memory ownership or will be forgotten here if GCd
		p.setValue(cast(Object)v.value);
	} else {
		nucleusError("{} (={}) is not a valid default value for a parameter.", v.classinfo.name, v);
	}
}


void buildConcreteParams(GraphDefNode node, ParamList* plist) {
	if (auto params_ = node.getVar("params")) {
		ParamDirection pdir;
		switch (node.type) {
			case "input": 
			case "data": pdir = ParamDirection.Out; break;
			case "output": pdir = ParamDirection.In; break;
			default: {
				error("Only input, output and data nodes may have params.");
			}
		}

		if (auto params = (cast(ParamListValue)params_).value) {
			buildConcreteParams(pdir, params, plist);
		} else {
			error("The 'params' field of a graph node must be a ParamListValue.");
		}
	}
}


void buildPlainSemantic(ParamSemanticExp sem, Semantic* psem) {
	void buildSemantic(ParamSemanticExp sem) {
		if (sem is null) {
			return;
		}
		
		if (sem) {
			if (ParamSemanticExp.Type.Sum == sem.type) {
				buildSemantic(sem.exp1);
				buildSemantic(sem.exp2);
			} else if (ParamSemanticExp.Type.Trait == sem.type) {
				psem.addTrait(sem.name, sem.value);
				// TODO: check the type?
			} else {
				// TODO: err
				nucleusError("Subtractive trait used in a node param.");
			}
		}
	}
	
	buildSemantic(sem);
}


void buildConcreteParams(ParamDirection pdir, ParamDef[] params, ParamList* plist) {
	foreach (d; params) {
		auto p = plist.add(
			pdir,
			d.name
		);

		setParamValue(p, d.defaultValue);

		p.hasPlainSemantic = true;
		final psem = p.semantic();

		if (d.type.length > 0) {
			p.type = d.type;
		}

		buildPlainSemantic(d.paramSemantic, psem);
	}
}
