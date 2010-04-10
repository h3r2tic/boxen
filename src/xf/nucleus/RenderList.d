module xf.nucleus.RenderList;

private {
	import xf.nucleus.Defs;
	import xf.omg.core.CoordSys;
	import xf.mem.MultiArray;
}



struct RenderList {
	mixin(multiArray(`list`, `
		RenderableId	renderableId
		CoordSys		coordSys
	`));

	uint add() {
		final res = list.length;
		return list.growBy(1);
	}

	void clear() {
		list.resize(0);
	}
}
