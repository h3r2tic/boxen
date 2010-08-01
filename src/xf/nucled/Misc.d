module xf.nucled.Misc;

private {
	import xf.hybrid.Hybrid;
}



struct PaddedProxy {
	vec2 padSize;
	
	void opAssign(void delegate() dg) {
		auto grp = VBox() [{
			dg();
		}];
		grp.layoutAttribs = "hexpand hfill vexpand vfill";
		auto box = cast(VBoxLayout)grp.layout;
		assert (box !is null);
		box.padding = padSize;
	}
}


PaddedProxy padded(float x, float y = float.nan) {
	return PaddedProxy(vec2(x, y <>= 0 ? y : x));
}



struct GlobalPosProxy {
	vec2 center;
	
	void opAssign(void delegate() dg) {
		auto grp = Group();
		grp [{
			auto wrap = Group() [{
				dg();
			}];
			
			wrap.parentOffset = center - wrap.size * .5 - grp.globalOffset;
		}];
		grp.layoutAttribs = "hexpand hfill vexpand vfill";
		if (!cast(GhostLayout)grp.layout) {
			grp.layout = new GhostLayout;
		}
	}
}

GlobalPosProxy globalPos(vec2 pt) {
	return GlobalPosProxy(pt);
}
