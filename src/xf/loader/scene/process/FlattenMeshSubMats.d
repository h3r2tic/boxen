module xf.loader.scene.process.FlattenMeshSubMats;

private {
	import xf.Common;
	
	import
		xf.loader.scene.model.Mesh,
		xf.loader.Log : log = loaderLog, error = loaderError;

	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys;
		
	import
		xf.mem.StackBuffer,
		xf.utils.Memory,
		xf.utils.LocalArray;
}


/// The new meshes array storage is only valid in the sink delegate
void flattenMeshSubMats(Mesh[] meshes, void delegate(Mesh[]) sink) {
	if (0 == meshes.length) {
		return;
	}
	
	int totalNumMeshes = 0;
	
	scope stackBuffer = new StackBuffer;
	
	auto usedIdsPerMesh = LocalArray!(uint[])(meshes.length, stackBuffer);
	scope (success) usedIdsPerMesh.dispose();
	
	foreach (i, ref m; meshes) {
		findSubMatIdsUsedByMesh(m, stackBuffer, (uint[] ids) {
			usedIdsPerMesh.data[i] = ids;
			totalNumMeshes += ids.length;
		});
	}
	
	auto newMeshes = LocalArray!(Mesh)(totalNumMeshes, stackBuffer);
	scope (success) newMeshes.dispose();
	
	flattenMeshSubMatsWorker(meshes, newMeshes.data, usedIdsPerMesh.data);
	foreach (ref m; newMeshes.data) {
		assert (m.faceSubMatIds() is null);
		assert (
			m.material is null
		||	0 == m.material.subMaterials.length,
			m.material.name
		);
	}
	
	sink(newMeshes.data);
}


private void flattenMeshSubMatsWorker(
	Mesh[] meshes,
	Mesh[] newMeshes,
	uint[][] usedIdsPerMesh
) {
	assert (meshes.length > 0);
	assert (newMeshes.length >= meshes.length);
	assert (usedIdsPerMesh.length == meshes.length);
	
	foreach (meshI, usedIds; usedIdsPerMesh) {
		if (1 == usedIds.length) {
			meshes[meshI].disposeFaceSubMatIds();
			if (
				meshes[meshI].material
			&&	meshes[meshI].material.subMaterials.length > 0
			) {
				meshes[meshI].material = meshes[meshI].material.subMaterials[0];
			}
			
			newMeshes[0] = meshes[meshI];
		} else {
			flattenMeshSubMatsWorker(
				meshes[meshI],
				newMeshes[0..usedIds.length],
				usedIds
			);
			
			meshes[meshI].dispose();
		}
		
		newMeshes = newMeshes[usedIds.length..$];
	}
}

private void flattenMeshSubMatsWorker(
	ref Mesh mesh,
	Mesh[] newMeshes,
	uint[] usedIds
) {
	assert (newMeshes.length > 1);
	assert (usedIds.length == newMeshes.length);
	
	foreach (meshI, subMatId; usedIds) {
		scope stackBuffer = new StackBuffer;
		auto newMesh = &newMeshes[meshI];
		
		if (mesh.material && mesh.material.subMaterials.length > 0) {
			newMesh.material = mesh.material.subMaterials[subMatId % $];
		} else {
			newMesh.material = mesh.material;
		}

		// Copy all vertex data; TODO: this could be optimized
		// to only copy what's needed
		
		newMesh.node = mesh.node;
		newMesh.normalsIndexed = mesh.normalsIndexed;

		if (mesh.positions.length) {
			newMesh.allocPositions(mesh.positions.length);
			newMesh.positions[] = mesh.positions;
		}
		
		if (mesh.normalsIndexed) {
			if (mesh.normals.length) {
				newMesh.allocNormals(mesh.normals.length);
				newMesh.normals[] = mesh.normals;
			}
		}

		if (mesh.tangents.length) {
			newMesh.allocTangents(mesh.tangents.length);
			newMesh.tangents[] = mesh.tangents;
		}
		
		if (mesh.bitangents.length) {
			newMesh.allocBitangents(mesh.bitangents.length);
			newMesh.bitangents[] = mesh.bitangents;
		}
		
		if (mesh.colors.length) {
			newMesh.allocColors(mesh.colors.length);
			newMesh.colors[] = mesh.colors;
		}
		
		final numTcSets = mesh.numTexCoordSets;

		if (numTcSets) {
			newMesh.allocTexCoordSets(numTcSets);
			for (int tcset = 0; tcset < numTcSets; ++tcset) {
				final oldSet = mesh.texCoords(tcset);
				final newSet = newMesh.texCoords(tcset);
				newSet.channel = oldSet.channel;
				
				if (oldSet.coords.length) {
					newSet.allocCoords(oldSet.coords.length);
					newSet.coords[] = oldSet.coords;
					assert (
						oldSet.indices is null
					||	oldSet.indices.length == mesh.indices.length
					);
				}
			}
		}
		
		// Count how many indices will be needed for this mesh
		
		uword numIndices = 0;
		foreach (smid; mesh.faceSubMatIds) {
			if (smid == subMatId) {
				numIndices += 3;
			}
		}
		
		
		// Allocate and copy the indices
		
		newMesh.allocIndices(numIndices);
		{
			uword vertsAdded = 0;
			foreach (face, smid; mesh.faceSubMatIds) {
				if (smid == subMatId) {
					auto oldFace = mesh.indices[face*3 .. face*3+3];
					auto newFace = newMesh.indices[vertsAdded .. vertsAdded+3];
					newFace[] = oldFace;
					vertsAdded += 3;
				}
			}
			
			assert (vertsAdded == newMesh.indices.length);
		}

		if (!mesh.normalsIndexed && mesh.normals.length) {
			newMesh.allocNormals(numIndices);
			{
				uword vertsAdded = 0;
				foreach (face, smid; mesh.faceSubMatIds) {
					if (smid == subMatId) {
						auto oldFace = mesh.normals[face*3 .. face*3+3];
						auto newFace = newMesh.normals[vertsAdded .. vertsAdded+3];
						newFace[] = oldFace;
						vertsAdded += 3;
					}
				}
				
				assert (vertsAdded == newMesh.indices.length);
			}
		}
		
		
		for (int tcset = 0; tcset < numTcSets; ++tcset) {
			final oldSet = mesh.texCoords(tcset);
			final newSet = newMesh.texCoords(tcset);
			if (oldSet.indices.length) {
				newSet.allocIndices(numIndices);

				{
					uword vertsAdded = 0;
					foreach (face, smid; mesh.faceSubMatIds) {
						if (smid == subMatId) {
							auto oldFace = oldSet.indices[face*3 .. face*3+3];
							auto newFace = newSet.indices[vertsAdded .. vertsAdded+3];
							newFace[] = oldFace;
							vertsAdded += 3;
						}
					}
					
					assert (vertsAdded == newMesh.indices.length);
				}
			}
		}
	}
}


/// If the mesh uses no sub-materials, yield just the number '0'
/// Otherwise, yield the set of sub-materials indices it uses
private void findSubMatIdsUsedByMesh(
	ref Mesh mesh,
	StackBufferUnsafe stackBuffer,
	void delegate(uint[]) sink
) {
	if (mesh.faceSubMatIds.length > 0) {
		uint maxId = 0;
		foreach (id; mesh.faceSubMatIds) {
			if (id > maxId) {
				maxId = id;
			}
		}
		
		bool[] idsUsed = stackBuffer.allocArray!(bool)(maxId+1);
		
		foreach (id; mesh.faceSubMatIds) {
			idsUsed[id] = true;
		}
		
		uint numIdsUsed = 0;
		uint[] usedIds = stackBuffer.allocArrayNoInit!(uint)(idsUsed.length);
		
		foreach (i, iu; idsUsed) {
			if (iu) {
				usedIds[numIdsUsed++] = i;
			}
		}
		
		sink(usedIds[0 .. numIdsUsed]);
	} else {
		uint id = 0;
		sink((&id)[0..1]);
	}
}
