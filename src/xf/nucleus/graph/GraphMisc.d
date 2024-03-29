module xf.nucleus.graph.GraphMisc;

private {
	import xf.Common;
	import xf.nucleus.graph.Graph;
	import xf.nucleus.graph.KernelGraph;
	import tango.text.convert.Format;
}



cstring toGraphviz(Graph graph) {
	char[] res;
	res ~= `Digraph G { graph [
		concentrate=false, remincross=true, labeljust=l, rankdir=LR,
		ratio=compress, nodesep=0.05,
		fontname=Verdana, fontsize=12];
		style = "filled"

		node [
			shape = "box"
			fontname = "Verdana"
			fontsize = 8
			style = "filled"
			pad = "0.0, 0.0"
			margin = "0.06, 0.03"
			width = 0
			height = 0
		];

		edge [
			fontname = "Verdana"
			fontsize = 10
			color = gray30
			weight = 1.5
		];
	`;
	
	cstring nodeName(GraphNodeId n) {
		return Format("{}", n.id);
	}

	foreach (n; graph.iterNodes) {
		cstring color = "#eeeeee";
		
		cstring prefix;// = n.primLevelStr ~ domainToString(n.domain) ~ ' ';
		cstring label = prefix ~ nodeName(n);
		
		res ~= Format(
			`
			subgraph "cluster_{0}" {{
				label="{2}"; fillcolor="{1}"; fontsize=8;`\n,
			nodeName(n),
			color,
			label
		);

		bool[cstring] outp, inp;

		bool needsAutoPort = false;
		
		foreach (n2; graph.iterOutgoingConnections(n)) {
			needsAutoPort = needsAutoPort || graph.hasAutoFlow(n, n2);
			foreach (fl; graph.iterDataFlow(n, n2)) {
				outp[fl.from] = true;
			}
		}

		foreach (n2; graph.iterIncomingConnections(n)) {
			needsAutoPort = needsAutoPort || graph.hasAutoFlow(n2, n);
			foreach (fl; graph.iterDataFlow(n2, n)) {
				inp[fl.to] = true;
			}
		}

		if (needsAutoPort) {
			res ~= Format(
				`
				"{0}.auto" [label="auto", fillcolor="#c0c0c0", fontname="Verdana Bold"];`\n,
				nodeName(n)
			);
		}

		foreach (inParam; inp.keys) {
			res ~= Format(
				`
				"in {0}.{2}" [label="{3}", fillcolor="#cceeff"];`\n,
				nodeName(n),
				color,
				inParam,
				inParam
				/+inParam.name,
				inParam.toString+/
			);
		}
		foreach (outParam; outp.keys) {
			res ~= Format(
				`
				"out {0}.{2}" [label="{3}", fillcolor="#ffeecc"];`\n,
				nodeName(n),
				color,
				outParam,
				outParam
				/+outParam.name,
				outParam.toString+/
			);
		}
		res ~= "}";
	}

	foreach (n1; graph.iterNodes) {
		foreach (n2; graph.iterOutgoingConnections(n1)) {
			foreach (fl; graph.iterDataFlow(n1, n2)) {
				res ~= Format(`"out {}.{}" -> "in {}.{}";`\n, nodeName(n1), fl.from, nodeName(n2), fl.to);
			}

			if (graph.hasAutoFlow(n1, n2)) {
				res ~= Format(`"{}.auto" -> "{}.auto"[ penwidth=1.5, color=black ];`\n, nodeName(n1), nodeName(n2));
			}
		}
	}
	
	res ~= "}";
	
	return res;
}



cstring toGraphviz(KernelGraph kgraph, cstring delegate(GraphNodeId) annotGen = null) {
	auto graph = kgraph.flow;
	
	char[] res;
	res ~= `Digraph G { graph [
		concentrate=false, remincross=true, labeljust=l, rankdir=LR,
		ratio=compress, nodesep=0.05,
		fontname=Verdana, fontsize=12];
		style = "filled"

		node [
			shape = "box"
			fontname = "Verdana"
			fontsize = 8
			style = "filled"
			pad = "0.0, 0.0"
			margin = "0.06, 0.03"
			width = 0
			height = 0
		];

		edge [
			fontname = "Verdana"
			fontsize = 10
			color = gray30
			weight = 1.5
		];
	`;
	
	cstring nodeName_(GraphNodeId n) {
		final node = kgraph.getNode(n);
		if (KernelGraph.NodeType.Func == node.type) {
			return Format(
				"{} - {}",
				n.id,
				node.func.func.name
			);
		} else if (KernelGraph.NodeType.Kernel == node.type) {
			return Format("{} - abstract {}",
				n.id,
				node.kernel.kernel.func.name
			);
		} else {
			return Format("{} - {}", n.id, node.typeString);
		}
	}
	
	cstring nodeName(GraphNodeId n) {
		if (annotGen) {
			return nodeName_(n) ~ annotGen(n);
		} else {
			return nodeName_(n);
		}
	}

	foreach (n; graph.iterNodes) {
		cstring color = "#eeeeee";
		
		cstring prefix;// = n.primLevelStr ~ domainToString(n.domain) ~ ' ';
		cstring label = prefix ~ nodeName(n);
		
		res ~= Format(
			`
			subgraph "cluster_{0}" {{
				label="{2}"; fillcolor="{1}"; fontsize=8;`\n,
			nodeName(n),
			color,
			label
		);

		bool[cstring] outp, inp;

		bool needsAutoPort = false;
		
		foreach (n2; graph.iterOutgoingConnections(n)) {
			needsAutoPort = needsAutoPort || graph.hasAutoFlow(n, n2);
			foreach (fl; graph.iterDataFlow(n, n2)) {
				outp[fl.from] = true;
			}
		}

		foreach (n2; graph.iterIncomingConnections(n)) {
			needsAutoPort = needsAutoPort || graph.hasAutoFlow(n2, n);
			foreach (fl; graph.iterDataFlow(n2, n)) {
				inp[fl.to] = true;
			}
		}

		if (needsAutoPort) {
			res ~= Format(
				`
				"{0}.auto" [label="auto", fillcolor="#c0c0c0", fontname="Verdana Bold"];`\n,
				nodeName(n)
			);
		}

		foreach (inParam; inp.keys) {
			res ~= Format(
				`
				"in {0}.{2}" [label="{3}", fillcolor="#cceeff"];`\n,
				nodeName(n),
				color,
				inParam,
				inParam
				/+inParam.name,
				inParam.toString+/
			);
		}
		foreach (outParam; outp.keys) {
			res ~= Format(
				`
				"out {0}.{2}" [label="{3}", fillcolor="#ffeecc"];`\n,
				nodeName(n),
				color,
				outParam,
				outParam
				/+outParam.name,
				outParam.toString+/
			);
		}
		res ~= "}";
	}

	foreach (n1; graph.iterNodes) {
		foreach (n2; graph.iterOutgoingConnections(n1)) {
			foreach (fl; graph.iterDataFlow(n1, n2)) {
				res ~= Format(`"out {}.{}" -> "in {}.{}";`\n, nodeName(n1), fl.from, nodeName(n2), fl.to);
			}

			if (graph.hasAutoFlow(n1, n2)) {
				res ~= Format(`"{}.auto" -> "{}.auto"[ penwidth=1.5, color=black ];`\n, nodeName(n1), nodeName(n2));
			}
		}
	}
	
	res ~= "}";
	
	return res;
}
