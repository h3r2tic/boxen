module xf.omg.geom.NormalQuantizer;

private {
	import xf.omg.core.LinearAlgebra;
}


private const numAxisCells = 64;
static assert (numAxisCells*numAxisCells*numAxisCells-1 <= uint.max);

struct QuantizedNormal {
	vec3	vec;
	
	
	static QuantizedNormal opCall(vec3 vec) {
		QuantizedNormal res;
		res.vec = vec;
		return res;
	}
	
	
	hash_t toHash() {
		hash_t res;
		
		hash_t cell(float f) {
			if (f <= -1f) return 0;
			if (f >= 1f) return numAxisCells - 1;
			hash_t res = cast(uint)(cast(float)numAxisCells * (f * 0.5f + 0.5f));
			
			assert (res <= numAxisCells);
			
			if (res == numAxisCells) return res - 1;
			return res;
		}
		
		res = cell(vec.x);
		res *= numAxisCells;
		res += cell(vec.y);
		res *= numAxisCells;
		res += cell(vec.z);
		return res;
	}
	
	
	// we want to quantize normals, not hash them exactly. trick the AA :P
	int opCmp(QuantizedNormal rhs) {
		return toHash - rhs.toHash;
	}
	
	bool opEquals(QuantizedNormal rhs) {
		return toHash == rhs.toHash;
	}
}
