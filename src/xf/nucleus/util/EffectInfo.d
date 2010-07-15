module xf.nucleus.util.EffectInfo;

private {
	import
		xf.Common,
		xf.utils.FormatTmp,
		xf.mem.MainHeap,
		xf.mem.ScratchAllocator;

	import
		xf.nucleus.Param,
		xf.nucleus.graph.KernelGraph;

	static import
		xf.nucleus.codegen.Rename;

	import
		xf.gfx.Effect;
}



// TODO: mem
struct EffectInfo {
	struct UniformDefaults {
		char[]	name;		// zero-terminated
		void[]	value;
	}

	UniformDefaults[]	uniformDefaults;
	Effect				effect;


	// NOTE: doesn't actually dispose the effect, only the info
	void dispose() {
		mainHeap.freeRaw(uniformDefaults.ptr);
		uniformDefaults = null;
		effect = null;
	}
}


void findEffectInfo(KernelGraph kg, EffectInfo* effectInfo) {
	assert (effectInfo !is null);

	void iterDataParams(void delegate(cstring name, Param* param) sink) {
		foreach (nid; kg.iterNodes) {
			final node = kg.getNode(nid);
			if (KernelGraph.NodeType.Data != node.type) {
				continue;
			}
			final pnode = node.data();

			foreach (ref p; pnode.params) {
				if (p.value) {
					formatTmp((Fmt fmt) {
						xf.nucleus.codegen.Rename.renameDataNodeParam(
							fmt,
							pnode,
							p.name
						);
					},
					(cstring s) {
						sink(s, &p);
					});
				}
			}
		}
	}

	uword numParams = 0;
	uword sizeReq = 0;

	iterDataParams((cstring name, Param* param) {
		sizeReq += name.length+1;	// stringz
		sizeReq += param.valueSize;
		sizeReq += EffectInfo.UniformDefaults.sizeof;
		++numParams;
	});

	final pool = PoolScratchAllocator(mainHeap.allocRaw(sizeReq)[0..sizeReq]);

	// free effectInfo.uniformDefaults.ptr to free the whole thing (I accidentally)
	effectInfo.uniformDefaults = pool.allocArray
		!(EffectInfo.UniformDefaults)(numParams);

	numParams = 0;
	iterDataParams((cstring name, Param* param) {
		final ud = &effectInfo.uniformDefaults[numParams];
		assert (param.valueType != ParamValueType.String, "TODO");
		ud.name = pool.dupStringz(name);
		ud.value = pool.dupArray(param.value[0..param.valueSize]);
		++numParams;
	});

	assert (pool.isFull());
}


void setEffectInstanceUniformDefaults(EffectInfo* effectInfo, EffectInstance efInst) {
	foreach (ud; effectInfo.uniformDefaults) {
		if (void** ptr = efInst.getUniformPtrPtr(ud.name)) {
			assert (*ptr, ud.name);
			memcpy(*ptr, ud.value.ptr, ud.value.length);
		}
	}				
}
