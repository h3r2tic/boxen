/*
	Generator of random numbers or vectors from different topological domains
	such as circles, boxes, etc.
*/
module xf.omg.rand.Topology;

private {
	import xf.omg.rand.MersenneTwister;
	import xf.omg.core.LinearAlgebra;

	import tango.math.Math;
}

//Type T may be one of the float, double or real
class Topology(T, Method = MersenneTwister) {

	alias Vector!(T, 3) TPoint3;
	alias Vector!(T, 2) TPoint2;

	final static T Point() {
		return 2*rand()-1.0;
	}

	final static TPoint2 Square() {
		return 2*TPoint2(rand(), rand()) - TPoint2.one;
	}

	final static TPoint2 Rect(T factor) {
		return 2*TPoint2(rand(), factor*rand()) - TPoint2(1.0,factor*1.0);
	}

	final static TPoint2 Circle() {
		TPoint2 p = Square();
		while (p.x*p.x + p.y*p.y > 1) {
			p = Square();
		}
		return p;
	}

	final static TPoint2 Disc(T innerRad) {
		T theta = 2*rand()*PI;
		T r = innerRad + (1-innerRad)*rand();

		return TPoint2(r*cos(theta),r*sin(theta));
	}

	final static TPoint3 Box() {
		return 2*TPoint3(rand(), rand(), rand()) - TPoint3.one;
	}

	final static TPoint3 Sphere() {
		TPoint3 p = Box();
		while (p.x*p.x + p.y*p.y + p.z*p.z > 1) {
			p = Box();
		}
		return p;
	}

	final static TPoint3 EmptySphere(T innerRad) {
		return (innerRad + (1-innerRad)*rand() ) * Sphere();
	}

	private {
		const static auto rand = &Method.shared.get!(T);
	}
}
