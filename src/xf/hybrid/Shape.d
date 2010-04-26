module xf.hybrid.Shape;

private {
	import xf.hybrid.Math : vec2;
}

public {
	import xf.hybrid.Rect : Rect;
}



///
abstract class Shape {
	///
	final Rect rect(vec2 size) {
		return Rect(vec2.zero, size);
	}
	
	
	///
	abstract void toPolygon(vec2 size, void delegate(vec2[]));
	
	///
	abstract void toLines(vec2 size, void delegate(vec2, vec2));
	
	///
	abstract bool contains(vec2 size, vec2 pt);
	
	///
	abstract Shape dup();
}


///
class Rectangle : Shape {
	override void toPolygon(vec2 size, void delegate(vec2[]) dg) {
		vec2[4] pts = void;
		pts[0] = vec2.zero;
		pts[1] = vec2(0, size.y);
		pts[2] = size;
		pts[3] = vec2(size.x, 0);
		dg(pts);
	}


	override void toLines(vec2 size, void delegate(vec2, vec2) dg) {
		vec2[4] pts = void;
		pts[0] = vec2.zero;
		pts[1] = vec2(0, size.y);
		pts[2] = size;
		pts[3] = vec2(size.x, 0);
		dg(pts[0], pts[1]);
		dg(pts[1], pts[2]);
		dg(pts[2], pts[3]);
		dg(pts[3], pts[0]);
	}


	override bool contains(vec2 size, vec2 pt) {
		return this.rect(size).contains(pt);
	}
	
	
	override Rectangle dup() {
		return new Rectangle;
	}
}
