module xf.hybrid.FontRenderer;

private {
	import xf.hybrid.IconCache;
	import xf.hybrid.Texture : Texture;
	import xf.hybrid.Math : vec2, vec4;
	import xf.hybrid.Rect;
}



///
enum BlendingMode {
	Alpha,
	Subpixel,
	None
}


///
interface FontRenderer {
	///
	void enableTexturing(Texture tex);
	
	///
	void blendingMode(BlendingMode);

	///
	void subpixelSamplingVector(vec2);
	
	///
	void absoluteQuad(vec2[] points, vec2[] texCoords);
	
	///
	Rect getClipRect();
	
	///
	IconCache iconCache();
}
