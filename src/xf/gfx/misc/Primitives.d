module xf.gfx.misc.Primitives;

private {
	import xf.omg.core.LinearAlgebra;
}


static this() {
	Cube.genData();
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
		
		genFace(vec3(-1, -1, 1),	[0, 1]);		// front
		genFace(vec3(1, -1, 1),		[2, 1]);		// right
		genFace(vec3(1, -1, -1),	[0, 1]);		// back
		genFace(vec3(-1, -1, -1),	[2, 1]);		// left
		genFace(vec3(-1, -1, -1),	[0, 2]);		// bottom
		genFace(vec3(-1, 1, 1),		[0, 2]);		// top
		
		assert (vert == positions.length);
		assert (ind == indices.length);
	}
}
