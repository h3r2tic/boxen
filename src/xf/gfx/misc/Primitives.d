module xf.gfx.misc.Primitives;

private {
	import xf.omg.core.LinearAlgebra;
}


static this() {
	Cube.genData();
	Cylinder.genData();
}


struct Cube {
static:
	vec3[24]	positions;
	vec3[24]	normals;
	vec2[24]	texCoords;
	uint[36]	indices;


	private void genData() {
		static vec3[3] ijk = [vec3.unitX, vec3.unitY, vec3.unitZ];
		int vert;
		int ind;
		
		void genFace(vec3 orig, int[] axes) {
			vec3 normal = cross(-orig.cell[axes[0]] * ijk[axes[0]], -orig.cell[axes[1]] * ijk[axes[1]]);
			void addVert(vec3 p, vec2 tc) {
				normals[vert] = normal;
				texCoords[vert] = tc;
				positions[vert++] = p;
			}

			static int[] indOff = [0, 1, 2, 0, 2, 3];
			foreach (off; indOff) {
				indices[ind++] = vert+off;
			}

			vec2i tc = vec2i.zero;
			for (int i = 0; i < 4; ++i) {
				addVert(orig, vec2.from(tc));
				tc.cell[i&1] ^= 1;
				orig.cell[axes[i&1]] *= -1;
			}
		}
		
		genFace(vec3(-0.5, -0.5, 0.5),		[0, 1]);		// front
		genFace(vec3(0.5, -0.5, 0.5),		[2, 1]);		// right
		genFace(vec3(0.5, -0.5, -0.5),		[0, 1]);		// back
		genFace(vec3(-0.5, -0.5, -0.5),		[2, 1]);		// left
		genFace(vec3(-0.5, -0.5, -0.5),		[0, 2]);		// bottom
		genFace(vec3(-0.5, 0.5, 0.5),		[0, 2]);		// top
		
		assert (vert == positions.length);
		assert (ind == indices.length);
	}
}


struct Cylinder {
static:
	vec3[]	positions;
	vec3[]	normals;
	//vec2[]	texCoords;
	uint[]	indices;


	private void genData() {
		vec3 pointA = vec3(0.0f, -0.5f, 0.0f);
		vec3 pointB = vec3(0.0f, 0.5f, 0.0f);
		float radius = 0.5f;

		vec3[]	pos;
		vec3[]	norm;
		uint[]	ind;
		
		const int sides = 8;
		
		vec3 Z = (pointB - pointA).normalized;
		vec3 X, Y;
		Z.formBasis(&X, &Y);
		
		final int LC = pos.length;	// lower center
		pos ~= pointA;
		norm ~= -Z;
		
		final int UC = pos.length;	// upper center
		pos ~= pointB;
		norm ~= Z;

		final int LB = pos.length;		// lower base
		
		// lower base positions
		for (int i = 0; i < sides; ++i) {
			float angle = pi * 2.f * i / sides;
			vec3 n = cos(angle) * X + sin(angle) * Y;
			pos ~= pointA + n * radius;
			norm ~= -Z;
		}
		
		final int UB = pos.length;	// upper base
		
		// upper base positions
		for (int i = 0; i < sides; ++i) {
			float angle = pi * 2.f * i / sides;
			vec3 n = cos(angle) * X + sin(angle) * Y;
			pos ~= pointB + n * radius;
			norm ~= Z;
		}
		
		final int LW = pos.length;	// lower wall base

		// lower base positions
		for (int i = 0; i < sides; ++i) {
			float angle = pi * 2.f * i / sides;
			vec3 n = cos(angle) * X + sin(angle) * Y;
			pos ~= pointA + n * radius;
			norm ~= n;
		}

		final int UW = pos.length;	// upper wall base
		
		// upper base positions
		for (int i = 0; i < sides; ++i) {
			float angle = pi * 2.f * i / sides;
			vec3 n = cos(angle) * X + sin(angle) * Y;
			pos ~= pointB + n * radius;
			norm ~= n;
		}

		assert (pos.length == norm.length);
		
		// lower base indices
		for (int i = 0, p = sides-1; i < sides; p = i, ++i) {
			ind ~= LC;
			ind ~= LB+i;
			ind ~= LB+p;
		}

		// upper base indices
		for (int i = 0, p = sides-1; i < sides; p = i, ++i) {
			ind ~= UC;
			ind ~= UB+p;
			ind ~= UB+i;
		}

		// walls
		for (int i = 0, p = sides-1; i < sides; p = i, ++i) {
			ind ~= LW+p;
			ind ~= UW+i;
			ind ~= UW+p;

			ind ~= LW+p;
			ind ~= LW+i;
			ind ~= UW+i;
		}
		
		positions = pos;
		normals = norm;
		indices = ind;
	}
}
