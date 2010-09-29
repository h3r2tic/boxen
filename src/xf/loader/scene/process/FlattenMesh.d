module xf.loader.scene.process.FlattenMesh;

private {
	import xf.Common;
	
	import
		xf.loader.scene.model.Mesh,
		xf.loader.Log : log = loaderLog, error = loaderError;

	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys,
		xf.omg.geom.NormalQuantizer;
		
	import xf.utils.Memory;

	import
		tango.util.container.Container,
		tango.util.container.HashMap;
}



void flattenMeshArrays(Mesh[] meshes) {
	foreach (ref m; meshes) {
		flattenSingleMesh(m);
	}
}


private void flattenSingleMesh(ref Mesh mesh) {
	assert (mesh.tangents() is null);		// TODO
	assert (mesh.bitangents() is null);		// TODO
	assert (mesh.indices.length > 0);
	
	foreach (i; mesh.indices) assert (i < mesh.positions.length);

	uint[] normalIndices;
	scope (exit) normalIndices.free();
	
	vec3[] quantizedNormals;
	{
		scope normalHash = new HashMap!(
			QuantizedNormal,
			uint,
			Container.hash,
			Container.reap,
			Container.Chunk
		);
		
		uint numNormals = 0;
		
		normalIndices.alloc(mesh.indices.length);
		quantizedNormals.alloc(mesh.indices.length);
		
		float hashCreaseAngleCos = cos(1.0f * deg2rad);
		
		foreach (int ni, vec3 n; mesh.normals) {
			QuantizedNormal qn = QuantizedNormal(n);
			uint* fnd = qn in normalHash;
			
			if (fnd !is null && dot(mesh.normals[*fnd], n) >= hashCreaseAngleCos) {
				normalIndices[ni] = *fnd;
			} else {
				normalIndices[ni] = numNormals;
				normalHash[qn] = numNormals;
				quantizedNormals[numNormals] = n;
				++numNormals;
			}
		}
		
		quantizedNormals.realloc(numNormals);
		
		
		float maxError = 0f;
		foreach (i, ni; normalIndices) {
			float error = (mesh.normals[i] - quantizedNormals[ni]).length;
			if (error > maxError) maxError = error;
		}
	}
	
	assert (normalIndices.length == mesh.indices.length);
	
	int numMaps = mesh.numTexCoordSets;
	log.trace("    {} maps", numMaps);
	
	// now fix indices
	
	uint[][] propertyIndices;
	
	propertyIndices.alloc(2 + numMaps);
	scope (exit) propertyIndices.free();
	
	propertyIndices[0] = mesh.indices;
	propertyIndices[1] = normalIndices;
	for (int i = 0; i < numMaps; ++i) {
		propertyIndices[2+i] = mesh.texCoords(i).indices;
	}
	
	Mesh mesh2;
	mesh2.material = mesh.material;
	mesh2.node = mesh.node;
	mesh2.normalsIndexed = true;

	mesh2.allocIndices(mesh.indices.length);
	uint[] finalIndices = mesh2.indices();

	remapIndices(propertyIndices, finalIndices);
	uint maxIndex = 0; {
		foreach (i; finalIndices) if (i > maxIndex) maxIndex = i;
	}
	
	log.trace("    {} indices, {} positions", mesh.indices.length, mesh.positions.length);
	log.trace("    {} unique vertices", maxIndex+1);

	{
		mesh2.allocPositions(maxIndex+1);
		vec3[] npositions = mesh2.positions();
		
		mesh2.allocNormals(maxIndex+1);
		vec3[] vnormals = mesh2.normals();

		vec3[] oldPositions = mesh.positions();
		vec3[] oldNormals = quantizedNormals;
		
		foreach (src, dst; finalIndices) {
			vec3 v = oldPositions[mesh.indices[src]];
			npositions[dst] = v;

			vec3 n = oldNormals[normalIndices[src]];
			vnormals[dst] = n;
		}
	}

	if (numMaps > 0) {
		bool includesColor = false;
		int colorSetIdx = 0;
		
		for (int i = 0; i < numMaps; ++i) {
			if (0 == mesh.texCoords(i).channel) {
				includesColor = true;
				colorSetIdx = i;
				break;
			}
		}
		
		int numTcMaps = numMaps - (includesColor ? 1 : 0);
		
		if (numTcMaps > 0) {
			mesh2.allocTexCoordSets(numTcMaps);
		}
		
		if (includesColor) {
			vec3[] oldColors = mesh.texCoords(colorSetIdx).coords;
			uint[] oldIndices = mesh.texCoords(colorSetIdx).indices;

			mesh2.allocColors(maxIndex+1);
			vec4[] colors = mesh2.colors();

			foreach (src, dst; finalIndices) {
				vec3 v = oldColors[oldIndices[src]];
				colors[dst] = vec4(v.r, v.g, v.b, 1);
			}
		}
		
		int dstMap = 0;
		for (int i = 0; i < numMaps; ++i) {
			if (!includesColor || i != colorSetIdx) {
				final tcSet = mesh.texCoords(i);
				
				final tcSet2 = mesh2.texCoords(dstMap);
				tcSet2.allocCoords(maxIndex+1);
				tcSet2.channel = tcSet.channel;
				vec3[] newCoords = tcSet2.coords;

				vec3[] oldCoords = tcSet.coords;
				uint[] oldIndices = tcSet.indices;
				
				foreach (src, dst; finalIndices) {
					vec3 v = oldCoords[oldIndices[src]];
					newCoords[dst] = v;
				}
				
				++dstMap;
			}
		}
		assert (dstMap == numTcMaps);
	}
	
	mesh.dispose();
	mesh = mesh2;
}


private void remapIndices(uint[][] propertyIndices, uint[] finalIndices) {
	assert (finalIndices.length > 0);
	
	assert (({
		foreach (pi; propertyIndices) {
			assert (pi.length == finalIndices.length);
		}
	}(), true));
	
	if (1 == propertyIndices.length) {
		finalIndices[] = propertyIndices[0][];
		return;
	}
	
	uint[] buffer;
	buffer.alloc(finalIndices.length);
	buffer[] = propertyIndices[0][];
	
	foreach (uint[] prop; propertyIndices[1..$]) {
		remapIndicesWorker(buffer, prop, finalIndices);
		
		if (prop is propertyIndices[$-1]) break;
		buffer[] = finalIndices[];
	}
	
	buffer.free();
}


void remapIndicesWorker(uint[] srcA, uint[] srcB, uint[] dst) {
	assert (({
		assert (srcA.length == srcB.length);
		assert (srcB.length == dst.length);
		assert (srcA !is srcB && srcA !is dst && srcB !is dst);
	}, true));

	struct IndexUnion {
		uint a, b;
		
		hash_t toHash() {
			return (a << 16) + (a & 0xffff0000) + b;
		}
	}
	
	
	scope newIndices = new HashMap!(IndexUnion, uint, Container.hash, Container.reap, Container.Chunk);
	uint newI = 0;
	
	for (uint i = 0; i < srcA.length; ++i) {
		auto iu = IndexUnion(srcA[i], srcB[i]);
		uint* indexP = iu in newIndices;
		
		if (indexP is null) {
			newIndices[iu] = newI;
			dst[i] = newI;
			++newI;
		} else {
			dst[i] = *indexP;
		}
	}
}
