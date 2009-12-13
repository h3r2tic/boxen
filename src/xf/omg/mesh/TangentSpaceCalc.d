module xf.omg.mesh.TangentSpaceCalc;

private {
	import xf.omg.core.LinearAlgebra;
	import xf.omg.mesh.Mesh : OmgMesh = Mesh, vertexI, faceI, Face, HEdge;
	import xf.omg.mesh.Logging;
	import xf.omg.geom.AABB;
	import xf.omg.geom.OCTree;
}




/**
	Controls vertex merging done for adjacency calculation.
	Vertices will be assumed the same if they fulfill the specific criteria.
	This is to assure that duplicated or similar vertices will have uniform tangential bases
*/
struct MeshAdjacencyOptions {
	bool	calculate = true;
	float	posMergeDist				= 0.01f;		// max position distance
	float	texCoordMergeDist	= 0.01f;		// max texCoord distance
	float	normalsMergeDot		= 0.95f;		// min cosine between normals
}


/**
	Calculates tangents and bitangents for a triangular mesh
	
	The tangent and bitangent arrays must be preallocated. All arrays must have the same length.
	TCType can be any vector with dim >= 2  ( conversion is done using vec2.from )
	
	Tangent spaces are calculated for each vertex by averaging trivially computed tangent spaces
	in each vertex edge ring.
*/

debug ( tangents ) {
 	import tango.io.Stdout;
}


void computeMeshTangents(TCType)(
		uint[] indices,
		vec3[] positions,
		vec3[] normals,
		TCType[] texCoords,
		vec3[] tangents,	// out
		vec3[] bitangents,	// out
		MeshAdjacencyOptions adjOpt = MeshAdjacencyOptions.init
) {
	debug (tangents) {
		Stdout(positions.length,  normals.length ,  texCoords.length,  tangents.length,  bitangents.length).newline;
	}
		
	assert (positions.length == normals.length);
	assert (positions.length == texCoords.length);
	assert (positions.length == tangents.length);
	assert (positions.length == bitangents.length);
	
	tangents[] = vec3.init;
	bitangents[] = vec3.init;
	
	foreach (n; normals) {
		assert (n.ok);
	}
	
	scope omgMesh = OmgMesh.fromTriList(cast(int[])indices);

	float pmd2 = adjOpt.posMergeDist * adjOpt.posMergeDist;
	float tcmd2 = adjOpt.texCoordMergeDist * adjOpt.texCoordMergeDist;	
	
	struct VHashData {
		vec3	position;
		vec2	tc;
		vec3	normal;
		int	idx;
	}
	alias OCTree!(VHashData) VHashOCTree;

	scope vhash = new VHashOCTree.Tree(AABB(positions));
	foreach (i, p; positions) {
		vhash.addData(VHashData(p, vec2.from(texCoords[i]), normals[i], i));
	}

	meshLog.msg("Computing adjacency ...");
	omgMesh.computeAdjacency((vertexI idx, void delegate(vertexI) adjIter) {
		if (adjOpt.calculate) {
			auto v0 = positions[idx];
			auto tc0 = vec2.from(texCoords[idx]);
			auto n0 = normals[idx];
			foreach (data; vhash.findData(v0, adjOpt.posMergeDist)) {
				if (
					(data.position - v0).sqLength <= pmd2 &&
					(data.tc - tc0).sqLength <= tcmd2 &&
					dot(data.normal, n0) >= adjOpt.normalsMergeDot
				) {
					if (idx != data.idx) {
						//meshLog.trace("{} is adjacent to {}", idx, data.idx);
						adjIter(cast(vertexI)data.idx);
					}
				}
			}
		}
	});
	meshLog.msg("Done.");
	
	bool addTangents(vec3 e0, vec3 e1, vec2 te0, vec2 te1, ref vec3 tangent, ref vec3 bitangent) {
		float cp = te0.x * te1.y - te0.y * te1.x;
		if (cp != 0.f) {
			float mul = 1.f / cp;
			tangent += (te1.y * e0 - te0.y * e1) * mul;//  e0 * -te1.y + e1 * te0.y) * mul;
			bitangent += (te0.x * e1 - te1.x * e0) * mul;//(e0 * -te1.x + e1 * te0.x) * mul;
			return true;
		} else {
			return false;
		}
	}


	void calcTangents(HEdge* h, ref vec3 tangent, ref vec3 bitangent) {
		tangent = vec3.zero;
		bitangent = vec3.zero;
		
		vec3 hnorm = normals[h.vi];
		vec2 htc = vec2.from(texCoords[h.vi]);
		vec3 hpos = positions[h.vi];
		
		bool success = false;
		
		void _addTangents(int v0, int v1) {
			vec3 e0 = positions[v0] - hpos;
			vec3 e1 = positions[v1] - hpos;
			
			if (dot(cross(e0, e1), hnorm) < 0.f) {
				success |= addTangents(
					e1, e0,
					vec2.from(texCoords[v1]) - htc, vec2.from(texCoords[v0]) - htc,
					tangent, bitangent
				);
			} else {
				success |= addTangents(
					e0, e1,
					vec2.from(texCoords[v0]) - htc, vec2.from(texCoords[v1]) - htc,
					tangent, bitangent
				);
			}
		}
		
		int hFirst = -1;
		int hLast = -1;
		foreach (hr; omgMesh.hedgeRing(h)) {
			auto i = hr.nextFaceHEdge(omgMesh).vi;
			if (-1 == hFirst) {
				hFirst = i;
			}
			if (hLast != -1) {
				_addTangents(hLast, i);
			}
			hLast = i;
		}
		
		if (hLast != -1) {
			_addTangents(hLast, hFirst);
		}
		
		if (success) {
			// orthogonalize tangents and bitangents against the normals
			tangent -= dot(hnorm, tangent) * hnorm;
			bitangent -= dot(hnorm, bitangent) * hnorm;
			
			tangent.normalize;
			bitangent.normalize;
		} else {
			tangent = bitangent = vec3.init;
		}
	}
	
	// TODO: this duplicates work, as each triangle will really the same basis (?)
	// BUG: _hedgeRing in Mesh currently doesn't do well for border hedges. these are handled in the next section
	uint faces = omgMesh.numFaces;
	for (int i = 0; i < faces; ++i) {
		auto face = omgMesh.face(cast(faceI)i);
		auto first = omgMesh.hedge(face.fhi);
		
		vec3 t, bt;
		calcTangents(first, t, bt);
		tangents[first.vi] = t;
		bitangents[first.vi] = bt;
	}
	
	// use lower-quality approximations for the vertices that failed the computation
	for (int triId = 0; triId < indices.length; triId += 3) {
		int i0 = indices[triId+0];
		int i1 = indices[triId+1];
		int i2 = indices[triId+2];
		bool i0ok = tangents[i0].ok;
		bool i1ok = tangents[i1].ok;
		bool i2ok = tangents[i2].ok;
		
		int validId = -1;
		if (i0ok) {
			validId = i0;
		} else if (i1ok) {
			validId = i1;
		} else if (i2ok) {
			validId = i2;
		}
		
		if (validId != -1) {
			if (!i0ok) {
				tangents[i0] = tangents[validId];
				bitangents[i0] = bitangents[validId];
			}
			if (!i1ok) {
				tangents[i1] = tangents[validId];
				bitangents[i1] = bitangents[validId];
			}
			if (!i2ok) {
				tangents[i2] = tangents[validId];
				bitangents[i2] = bitangents[validId];
			}
		} else {
			vec3 e0 = positions[i1] - positions[i0];
			vec3 e1 = positions[i2] - positions[i0];
			vec2 te0 = vec2.from(texCoords[i1]) - vec2.from(texCoords[i0]);
			vec2 te1 = vec2.from(texCoords[i2]) - vec2.from(texCoords[i0]);
			vec3 t = vec3.zero, bt = vec3.zero;
			
			vec3 norm = normals[i0] + normals[i1] + normals[i2];
			norm.normalize;

			if (norm.ok) {
				if (addTangents(e0, e1, te0, te1, t, bt)) {
					// orthogonalize tangents and bitangents against the normals
					t -= dot(norm, t) * norm;
					bt -= dot(norm, bt) * norm;
					
					t.normalize;
					bt.normalize;
				} else {
					// omgwtfbbq :S do anything! quick!
					norm.formBasis(&t, &bt);
				}
			} else {
				assert (false, "what the fsck.");
			}
			
			tangents[i0] = tangents[i1] = tangents[i2] = t;
			bitangents[i0] = bitangents[i1] = bitangents[i2] = bt;
		}
	}
}
