module xf.nucled.Dump;

private {
	import xf.Common;
	import xf.nucled.Graph;
	import xf.nucled.Settings;

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
	
	print.formatln(`{} = graph {{`, label);
	dumpGraph(graph, print);
	print.formatln(`};`);
	print.flush;
	cond.flush;
}


private void dumpGraph(Graph graph, FormatOutput!(char) p) {
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
}


private void dumpGraphNode(GraphNode n, FormatOutput!(char) p) {
	p.formatln(`node_{} = node {{`, n.id);
		p.formatln(\t`type = {};`, n.typeName);
		
		if (n.isKernelBased) {
			p.formatln(\t`kernel = {};`, n.kernelName);
		} else {
			if (n.data.params.length > 0) {
				p(\t`params = (`\n);
				int i = 0;
				foreach (ref param; n.data.params) {
					p.format(\t\t`{}`, param.toString);

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
