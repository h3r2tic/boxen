module xf.loader.scene.model.Mesh;

private {
	import xf.loader.scene.model.WorldEntity;
	import xf.loader.scene.model.Material;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.rt.Common : Ray, Hit;
	import xf.omg.geom.Triangle : intersectTriangle;
	import xf.utils.Memory;
	import xf.loader.scene.model.Node;
}



struct Mesh {
	Material	material;
	Node		node;
	
	// vertex indices and params
	uint[]		indices() {
		return _indices;
	}
	
	vec3[]		positions() {
		return _positions;
	}
	
	vec3[]		normals() {
		return _normals;
	}
	vec3[]		tangents() {
		return _tangents;
	}
	vec3[]		bitangents() {
		return _bitangents;
	}
	
	TexCoordSet* texCoords(int i) {
		return &_texCoords[i];
	}
	
	int numTexCoordSets() {
		return _texCoords.length;
	}
	
	vec4[]		colors() {
		return _colors;
	}
	


	void allocIndices(int n) {
		_indices.alloc(n);
	}
	
	void allocPositions(int n) {
		_positions.alloc(n);
	}
	
	void allocNormals(int n) {
		_normals.alloc(n);
	}
	
	void allocTangents(int n) {
		_tangents.alloc(n);
	}
	
	void allocBitangents(int n) {
		_bitangents.alloc(n);
	}
	
	void allocTexCoordSets(int n) {
		_texCoords.alloc(n);
	}
	
	void allocColors(int n) {
		_colors.alloc(n);
	}
	

	bool intersect(Ray r, Hit* hit) {
		float dist = float.max;
		if (hit !is null) {
			dist = hit.distance;
		}

		for (int i = 0; i+2 < indices.length; i += 3) {
			vec3[3] verts = void;
			verts[0] = positions[indices[i+0]];
			verts[1] = positions[indices[i+1]];
			verts[2] = positions[indices[i+2]];
			
			if (intersectTriangle(verts[], r.origin, r.direction, dist)) {
				if (hit !is null) {
					hit.distance = dist;
				}
				return true;
			}
		}
		
		return false;
	}
	
	
	void dispose() {
		_indices.free();
		_positions.free();
		_normals.free();
		_tangents.free();
		_bitangents.free();
		foreach (ref tc; _texCoords) tc.dispose();
		_texCoords.free();
		_colors.free();
	}
	
	
	public {
		uint[]		_indices;
		
		vec3[]		_positions;
		
		vec3[]		_normals;
		vec3[]		_tangents;
		vec3[]		_bitangents;
		
		struct TexCoordSet {
			private {
				uint[]	_indices;
				vec3[]	_coords;
			}
			
			public {
				int	channel;
			}

			uint[] indices() {
				return _indices;
			}
			
			vec3[] coords() {
				return _coords;
			}

			void allocIndices(int n) {
				_indices.alloc(n);
			}
			
			void allocCoords(int n) {
				_coords.alloc(n);
			}
			
			void dispose() {
				_indices.free();
				_coords.free();
			}
			
			void disposeIndices() {
				_indices.free();
			}
		}
		
		TexCoordSet[]	_texCoords;
		
		vec4[]		_colors;
	}
}
