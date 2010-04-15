module xf.nucleus.GraphMisc;

private {
	import xf.Common;
	import xf.nucleus.Graph;
	import tango.text.convert.Format;
}



cstring toGraphviz(Graph graph) {
	char[] res;
	res ~= `Digraph G { graph [concentrate=true, remincross=true, labeljust=l, ratio=compress, nodesep=0.2, fontname=Helvetica, rankdir=LR];`\n;
	res ~= ` node [ fontname=Verdana ];`\n;
	
	cstring nodeName(GraphNodeId n) {
		return Format("{}", n.id);
	}

	foreach (n; graph.iterNodes) {
		cstring color = "#eeeeee";
		
		cstring prefix;// = n.primLevelStr ~ domainToString(n.domain) ~ ' ';
		cstring label = prefix ~ nodeName(n);
		
		/+if (auto calc = cast(CalcNode)n) {
			label = prefix ~ Format("{}:{}", calc.quark.kernelName, n.id);
		} else if (auto calc = cast(DemuxNode)n) {
			label = prefix ~ Format("{}:{}", calc.quark.kernelName, n.id);
		}+/
//			Stdout.formatln(label);
		
		res ~= Format(
				"subgraph \"cluster_{0}\" {{\n shape=\"box\"; style=\"filled\"; label=\"{2}\"; fillcolor=\"{1}\"; fontsize=8;\n",
				nodeName(n),
				color,
				label
		);

		bool[cstring] outp, inp;
		
		foreach (n2; graph.iterOutgoingConnections(n)) {
			foreach (fl; graph.iterDataFlow(n, n2)) {
				outp[fl.from] = true;
			}
		}

		foreach (n2; graph.iterIncomingConnections(n)) {
			foreach (fl; graph.iterDataFlow(n2, n)) {
				inp[fl.to] = true;
			}
		}

		foreach (inParam; inp.keys) {
			res ~= Format(
				`"in {0}.{2}" [shape="box",style="filled", label="{3}", fillcolor="#cceeff", fontsize=7];`\n,
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
				`"out {0}.{2}" [shape="box",style="filled", label="{3}", fillcolor="#ffeecc", fontsize=7];`\n,
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
				res ~= Format(`"out {}.{}" -> "in {}.{}"[color=gray30, weight=1.5 ];`\n, nodeName(n1), fl.from, nodeName(n2), fl.to);
			}/+ else {
				auto n2 = con.to;
				res ~= Format(`"cluster_{}" -> "cluster_{}"[color=gray30, weight=1.5 ];`\n, nodeName(n1), nodeName(n2));
			}+/
		}
	}
	
	res ~= "}";
	
	return res;
}
