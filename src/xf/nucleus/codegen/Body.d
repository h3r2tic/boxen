module xf.nucleus.codegen.Body;

private {
	import
		xf.Common;

	import
		xf.nucleus.Param,
		xf.nucleus.codegen.Defs,
		xf.nucleus.codegen.Rename,
		xf.nucleus.graph.KernelGraph,
		xf.nucleus.graph.KernelGraphOps;
}



void domainCodegenBody(
	CodegenContext ctx,
	void delegate(void delegate(GraphNodeId)) nodesTopo,
	cstring[] node2funcName,
	cstring[] node2compName
) {
	alias KernelGraph.NodeType NT;


	auto sink = ctx.sink;

	nodesTopo((GraphNodeId nid) {
		auto node = ctx.graph.getNode(nid);

		// TODO: remove Bridge nodes and redirect their flow after auto conversion
		// have been carried out, so that this step doen't have to be done
		if (NT.Bridge == node.type) {
			auto params = &node.bridge().params;
			
			foreach (par; *params) {
				assert (par.hasTypeConstraint);
				ctx.indent();
				sink(par.type)(' ');
				emitSourceParamName(ctx, nid, par.name);
				sink(" = ");

				GraphNodeId	srcNid;
				Param*		srcParam;

				if (!findSrcParam(
					ctx.graph,
					nid,
					par.name,
					&srcNid,
					&srcParam
				)) {
					error(
						"No flow to {}.{}. Should have been caught earlier.",
						nid.id,
						par.name
					);
				}

				emitSourceParamName(ctx, srcNid, srcParam.name);

				sink(';').newline();
			}
		} else if (NT.Composite == node.type) {
			auto compName = node2compName[nid.id];
			assert (compName !is null);

			ctx.indent()(compName)(' ');
			const compOutputName = "kernel";	// TODO: move the name to a common place
			emitSourceParamName(ctx, nid, compOutputName);
			sink(';').newline();

			auto params = &node.composite().params;
			
			foreach (i, par; *params) {
				if (par.isInput) {
					ctx.indent();

					emitSourceParamName(ctx, nid, compOutputName);
					sink('.');
					sink(par.name)(" = ");

					GraphNodeId	srcNid;
					Param*		srcParam;

					if (!findSrcParam(
						ctx.graph,
						nid,
						par.name,
						&srcNid,
						&srcParam
					)) {
						error(
							"No flow to {}.{}. Should have been caught earlier.",
							nid.id,
							par.name
						);
					}

					emitSourceParamName(ctx, srcNid, srcParam.name);

					sink(';').newline();
				}
			}
		} else if (NT.Func == node.type) {
			auto params = &node.func().params;
			
			foreach (par; *params) {
				assert (par.hasTypeConstraint);
				
				if (par.isOutput) {
					ctx.indent();
					sink(par.type)(' ');
					emitSourceParamName(ctx, nid, par.name);
					sink(';').newline();
				}
			}

			auto funcName = node2funcName[nid.id];
			assert (funcName !is null);
			
			ctx.indent()(funcName)('(').newline;
			foreach (i, par; *params) {
				ctx.indent()('\t');

				if (par.isInput) {
					GraphNodeId	srcNid;
					Param*		srcParam;

					if (!findSrcParam(
						ctx.graph,
						nid,
						par.name,
						&srcNid,
						&srcParam
					)) {
						error(
							"No flow to {}.{}. Should have been caught earlier.",
							nid.id,
							par.name
						);
					}

					emitSourceParamName(ctx, srcNid, srcParam.name);
				} else {
					emitSourceParamName(ctx, nid, par.name);
				}
				
				if (i+1 != params.length) {
					sink(',');
				}
				sink.newline();
			}
			ctx.indent()(");").newline;
		}
	});
}
