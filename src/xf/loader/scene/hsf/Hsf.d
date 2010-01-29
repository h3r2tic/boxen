module xf.loader.scene.hsf.Hsf;

private {
	import xf.Common;
	
	import
		xf.loader.scene.model.all,
		xf.loader.scene.hsf.Log,
		xf.loader.scene.process.FlattenMesh,
		xf.loader.scene.process.FlattenMeshSubMats;
		
	import
		xf.utils.LexerBase;
	
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.CoordSys,
		xf.omg.geom.NormalQuantizer,
		xf.omg.mesh.TangentSpaceCalc;
	
	import
		tango.io.FilePath,
		tango.io.device.File,
		tango.io.stream.Buffered,
		tango.util.container.Container,
		tango.util.container.HashMap,
		tango.io.model.IConduit : InputStream;
}



class HsfLoader {
	void load(cstring filename) {
		hsfLog.info("Loading a HSF scene from '{}'", filename);
		
		{
			scope f = new File(filename, File.ReadExisting);
			scope buf = new BufferedInput(f);
			parseAndLoad(buf);
		}
		
		hsfLog.trace("HSF file parsed successfully.");
		
		flattenMeshSubMats(meshes, (Mesh[] newMeshes) {
			xf.utils.Memory.realloc(meshes, newMeshes.length);
			meshes[] = newMeshes;
		});
		flattenMeshArrays(meshes);
		
		foreach (ref mesh; meshes) {
			computeExtraMeshData(mesh);
		}
	}
	
	void computeExtraMeshData(ref Mesh mesh) {
		if (
			mesh._normals.length > mesh._tangents.length
		&&	mesh.numTexCoordSets > 0
		&&	mesh.texCoords(0).coords.length > 0
		) {
			mesh.allocTangents(mesh._normals.length);
			mesh.allocBitangents(mesh._normals.length);
			
			hsfLog.trace("Calculating tangents and bitangents.");
			
			computeMeshTangents ( 
				mesh._indices,
				mesh._positions,
				mesh._normals,
				mesh._texCoords[0].coords,
				mesh._tangents,
				mesh._bitangents
			);
		}
	}
	
	
	float	scale = 1.f;
	Scene	scene;

	Mesh[]		meshes;
	Node[]		nodes;
	Material[]	materials;

	
protected:

	void parseAndLoad(InputStream stream) {
		char[256] peekBuf;
		final lexer = LexerBase(stream, cast(string)peekBuf[]);
		
		while (true) {
			cstring ident;
			lexer.skipWhite();
			if (lexer.eof) {
				break;
			}
			
			if (!lexer.consumeIdent(&ident)) {
				lexer.error("Expected an identifier.");
			}
			
			switch (ident) {
				case "meshes": {
					parseMeshes(&lexer);
				} break;
				
				case "nodes": {
					parseNodes(&lexer);
				} break;
				
				case "materials": {
					parseMaterials(&lexer);
				} break;

				default: {
					lexer.error("Unrecognized block in HSF file: '{}'", ident);
				} break;
			}
		}
		
		this.scene = new Scene;
		foreach (n; this.nodes) {
			if (n.parent is null) {
				scene.nodes ~= n;
			}
		}
	}
	

	void parseMeshes(LexerBase* lexer) {
		lexer.skipWhite();

		int numMeshes;
		if (!lexer.consumeInt(&numMeshes)) {
			lexer.error("Expected mesh count.");
		}
		
		xf.utils.Memory.alloc(meshes, numMeshes);
		
		for (int i = 0; i < numMeshes; ++i) {
			parseMesh(lexer, i);
		}
	}

	
	void parseMesh(LexerBase* lexer, int meshIdx) {
		lexer.skipWhite();
		if (lexer.peek() != '{') {
			lexer.error("Expected a mesh body. Got '{}'.", lexer.peek(0, 20));
		}
		lexer.consume();
		lexer.skipWhite();
		
		final mesh = &meshes[meshIdx];
		mesh.normalsIndexed = false;
		
		int		numPositions = 0;
		int		numIndices = 0;
		int		nodeId;
		int		numMaps;
		
		while (lexer.peek() != '}' && !lexer.eof) {
			cstring ident;
			if (!lexer.consumeIdent(&ident)) {
				lexer.error("Expected an identifier.");
			}
			
			lexer.skipWhite();

			switch (ident) {
				case "node": {
					if (!lexer.consumeInt(&nodeId)) {
						lexer.error("The 'node' property must be an integer.");
					}
					
					mesh.node = this.nodes[nodeId];
				} break;

				case "material": {
					int materialId;
					
					if (!lexer.consumeInt(&materialId)) {
						lexer.error("The 'material' property must be an integer.");
					}
					
					mesh.material = &this.materials[materialId];
				} break;

				case "indices": {
					if (!lexer.consumeInt(&numIndices)) {
						lexer.error("The 'indices' property must be an integer array.");
					}
					
					mesh.allocIndices(numIndices);
					
					for (int i = 0; i < numIndices; ++i) {
						lexer.skipWhite;
						
						int idx;
						if (!lexer.consumeInt(&idx)) {
							lexer.error("Syntax error in the indices array.");
						}
						
						mesh.indices[i] = idx;
					}
				} break;

				case "faceSubMats": {
					int numFaces_;
					if (!lexer.consumeInt(&numFaces_)) {
						lexer.error("The 'faceSubMats' property must be an integer array.");
					}
					
					assert (numFaces_ * 3 == numIndices);
					mesh.allocFaceSubMatIds(numFaces_);
					
					for (int i = 0; i < numFaces_; ++i) {
						lexer.skipWhite;
						
						int matIdx;
						if (!lexer.consumeInt(&matIdx)) {
							lexer.error("Syntax error in the submaterial index array.");
						}
						
						mesh.faceSubMatIds[i] = matIdx;
					}
				} break;

				case "positions": {
					if (!lexer.consumeInt(&numPositions)) {
						lexer.error("The 'positions' property must be a vec3 hex array.");
					}
					
					lexer.skipWhite;
					
					mesh.allocPositions(numPositions);

					for (int i = 0; i < numPositions; ++i) {
						vec3 pos;
						if (!lexer.readHexData(cast(u32[])(&pos)[0..1])) {
							lexer.error("Syntax error in the position array.");
						}
						
						mesh.positions[i] = pos;
					}
				} break;

				case "normals": {
					int numNormals;
					
					if (!lexer.consumeInt(&numNormals)) {
						lexer.error("The 'normals' property must be a vec3 hex array.");
					}
					
					lexer.skipWhite;
					
					mesh.allocNormals(numNormals);
					assert (numNormals == numIndices);

					for (int i = 0; i < numNormals; ++i) {
						vec3 norm;
						if (!lexer.readHexData(cast(u32[])(&norm)[0..1])) {
							lexer.error("Syntax error in the normals array.");
						}
						
						if (norm.ok && norm.isUnit) {
							mesh.normals[i] = norm;
						} else {
							// has to be something... :S
							mesh.normals[i] = vec3.unitY;
						}
					}
				} break;

				case "maps": {
					if (!lexer.consumeInt(&numMaps)) {
						lexer.error("The 'maps' property must be a struct array.");
					}
					
					mesh.allocTexCoordSets(numMaps);
					
					for (int i = 0; i < numMaps; ++i) {
						parseMeshMapCoords(lexer, mesh.texCoords(i));
					}
				} break;
				
				default: {
					lexer.error("Unsupported mesh property: '{}'", ident);
				} break;
			}

			lexer.skipWhite();
		}
		
		if (lexer.eof) {
			lexer.error("End of file while parsing a mesh body.");
		}
		
		lexer.consume();		// eat the '}'
	}


	void parseMeshMapCoords(LexerBase* lexer, Mesh.TexCoordSet* coordSet) {
		lexer.skipWhite();
		if (lexer.peek() != '{') {
			lexer.error("Expected a mesh coords body. Got '{}'.", lexer.peek(0, 20));
		}
		lexer.consume();
		lexer.skipWhite();
		
		int		numCoords = 0;
		int		numIndices = 0;
		int		channelId;
		
		while (lexer.peek() != '}' && !lexer.eof) {
			cstring ident;
			if (!lexer.consumeIdent(&ident)) {
				lexer.error("Expected an identifier.");
			}
			
			lexer.skipWhite();

			switch (ident) {
				case "channel": {
					if (!lexer.consumeInt(&channelId)) {
						lexer.error("The 'channel' property must be an integer.");
					}
					
					coordSet.channel = channelId;
				} break;

				case "indices": {
					if (!lexer.consumeInt(&numIndices)) {
						lexer.error("The 'indices' property must be an integer array.");
					}
					
					coordSet.allocIndices(numIndices);
					
					for (int i = 0; i < numIndices; ++i) {
						lexer.skipWhite;
						
						int idx;
						if (!lexer.consumeInt(&idx)) {
							lexer.error("Syntax error in the indices array.");
						}
						
						coordSet.indices[i] = idx;
					}
				} break;

				case "coords": {
					if (!lexer.consumeInt(&numCoords)) {
						lexer.error("The 'coords' property must be a vec2 hex array.");
					}
					
					lexer.skipWhite;
					
					coordSet.allocCoords(numCoords);

					for (int i = 0; i < numCoords; ++i) {
						vec3 uvw;
						if (!lexer.readHexData(cast(u32[])(&uvw)[0..1])) {
							lexer.error("Syntax error in the coords array.");
						}
						coordSet.coords[i] = uvw;
					}
				} break;
				
				default: {
					lexer.error("Unsupported mesh map coord property: '{}'", ident);
				} break;
			}

			lexer.skipWhite();
		}
		
		if (lexer.eof) {
			lexer.error("End of file while parsing a mesh coords body.");
		}
		
		lexer.consume();		// eat the '}'
	}


	void parseNodes(LexerBase* lexer) {
		lexer.skipWhite();

		int numNodes;
		if (!lexer.consumeInt(&numNodes)) {
			lexer.error("Expected node count.");
		}
		
		nodes = new Node[numNodes];
		foreach (ref n; nodes) {
			n = new Node;
		}		
		
		for (int i = 0; i < numNodes; ++i) {
			parseNode(lexer, i);
		}
	}
	
	
	void parseNode(LexerBase* lexer, int nodeIdx) {
		lexer.skipWhite();
		if (lexer.peek() != '{') {
			lexer.error("Expected a node body. Got '{}'.", lexer.peek(0, 20));
		}
		lexer.consume();
		lexer.skipWhite();
		
		final node = nodes[nodeIdx];
		
		cstring nodeName = null;
		int		parent = -1;
		vec3	translation = vec3.zero;
		vec4	rotation = vec4.unitZ;
		
		while (lexer.peek() != '}' && !lexer.eof) {
			cstring ident;
			if (!lexer.consumeIdent(&ident)) {
				lexer.error("Expected an identifier.");
			}
			
			lexer.skipWhite();

			switch (ident) {
				case "name": {
					if (!lexer.consumeString((char c) {
						// TODO: mem
						nodeName ~= c;
					})) {
						lexer.error("The 'name' property must be a string.");
					}
				} break;

				case "parent": {
					if (!lexer.consumeInt(&parent)) {
						lexer.error("The 'parent' property must be an integer.");
					}
				} break;

				case "translation": {
					if (!lexer.readHexData(cast(u32[])(&translation)[0..1])) {
						lexer.error("The 'translation' property must be a hex vec3.");
					}
				} break;

				case "rotation": {
					if (!lexer.readHexData(cast(u32[])(&rotation)[0..1])) {
						lexer.error("The 'rotation' property must be a hex vec4.");
					}
				} break;

				default: {
					lexer.error("Unsupported node property: '{}'", ident);
				} break;
			}

			lexer.skipWhite();
		}

		CoordSys cs = void; {
			if (abs(rotation.a) > 0.0001f) {
				vec3 axis = vec3.from(rotation);
				axis.normalize();
				cs = CoordSys(
					vec3fi.from(translation/+ * scale+/),
					quat.axisRotation(axis, rotation.a)
				);
			} else {
				cs = CoordSys(
					vec3fi.from(translation/+ * scale+/),
					quat.identity
				);
			}
		}
		
		if (parent != -1) {
			assert (parent < nodeIdx);
			node.parent = nodes[parent];
		}

		node.setTransform(cs, node.parentCS);
		
		if (lexer.eof) {
			lexer.error("End of file while parsing a node body.");
		}
		
		lexer.consume();		// eat the '}'
	}







	int _lastParsedMat;

	void parseMaterials(LexerBase* lexer) {
		lexer.skipWhite();

		int numMaterials;
		if (!lexer.consumeInt(&numMaterials)) {
			lexer.error("Expected mesh count.");
		}
		
		xf.utils.Memory.alloc(materials, numMaterials);
		
		int matIdx = 0;
		_lastParsedMat = -1;
		for (int i = 0; i < numMaterials; ++i) {
			parseMaterial(lexer, matIdx);
		}
	}

	
	int parseMaterial(LexerBase* lexer, ref int matIdx) {
		lexer.skipWhite();
		{
			char ch = lexer.peek();
			if (ch < '0' || ch > '9') {
				if (lexer.peek(0, 4) == "null") {
					lexer.consume(4);
					return -1;
				} else {
					lexer.error("Expected a material body. Got '{}'.", lexer.peek(0, 20));
				}
			} else {
				int hsfMatId;
				if (!lexer.consumeInt(&hsfMatId)) {
					lexer.error("The material id must be an integer.");
				}

				if (hsfMatId <= _lastParsedMat) {
					return hsfMatId;		// already loaded
				} else {
					if (hsfMatId != matIdx) {
						hsfError(
							"Material ID counting mismatch. Hsf file: {}"
							", loader calculated: {}", hsfMatId, matIdx
						);
					}
					_lastParsedMat = matIdx;
				}
			}
		}
		
		lexer.skipWhite();
		
		if (lexer.peek() != '{') {
			lexer.error("Expected a material body. Got '{}'.", lexer.peek(0, 20));
		}
		
		lexer.consume();
		lexer.skipWhite();
		
		final material = &materials[matIdx];
		final resultMatIdx = matIdx;
		++matIdx;
		
		cstring matType;
		cstring matName;
		cstring shaderType;
		
		bool allowSubMats = false;
		
		while (lexer.peek() != '}' && !lexer.eof) {
			cstring ident;
			if (!lexer.consumeIdent(&ident)) {
				lexer.error("Expected an identifier.");
			}
			
			lexer.skipWhite();

			switch (ident) {
				case "name": {
					if (!lexer.consumeString((char c) {
						// TODO: mem
						matName ~= c;
					})) {
						lexer.error("The 'name' property must be a string.");
					}

					// TODO: mem
					cstring foo;
					xf.utils.Memory.alloc(foo, matName.length);
					foo[] = matName;
					material.name = foo;
				} break;

				case "type": {
					if (!lexer.consumeString((char c) {
						// TODO: mem
						matType ~= c;
					})) {
						lexer.error("The 'type' property must be a string.");
					}
					
					switch (matType) {
						case "standard": {
							allowSubMats = false;
						} break;

						case "multi": {
							allowSubMats = true;
						} break;
						
						default: {
							lexer.error("Unsupported material type: '{}'", matType);
						}
					}
				} break;
				
				case "sub": {
					if (!allowSubMats) {
						lexer.error("The '{}' material type doesn't allow sub-materials", matType);
					}
					
					lexer.skipWhite();
					int numSubMats;
					if (!lexer.consumeInt(&numSubMats)) {
						lexer.error("Expected the sub-material count.");
					}
					
					// TODO: mem
					xf.utils.Memory.alloc(material.subMaterials, numSubMats);
					
					for (int sub = 0; sub < numSubMats; ++sub) {
						int subId = parseMaterial(lexer, matIdx);
						if (subId != -1) {
							material.subMaterials[sub] = &this.materials[subId];
						}
					}
				} break;
				
				case "maps": {
					lexer.skipWhite();
					int numMaps;
					if (!lexer.consumeInt(&numMaps)) {
						lexer.error("Expected the map count.");
					}

					// TODO: mem
					xf.utils.Memory.alloc(material.maps, numMaps);
					
					for (int i = 0; i < numMaps; ++i) {
						parseMaterialMap(lexer, &material.maps[i]);
					}
				} break;

				// usual props

				case "shader": {
					if (!lexer.consumeString((char c) {
						// TODO: mem
						shaderType ~= c;
					})) {
						lexer.error("The 'shader' property must be a string.");
					}
					
					// TODO: mem
					cstring foo;
					xf.utils.Memory.alloc(foo, shaderType.length);
					foo[] = shaderType;
					material.reflectanceModel = foo;
				} break;
				
				case "diffuseTint": {
					vec3 rgb;
					if (!lexer.consumeFloatArray((&rgb.r)[0..3])) {
						lexer.error("The 'diffuseTint' property must be a vec3.");
					}
					
					material.diffuseTint = vec4(rgb.r, rgb.g, rgb.b, 1);
				} break;
				
				case "specularTint": {
					vec3 rgb;
					if (!lexer.consumeFloatArray((&rgb.r)[0..3])) {
						lexer.error("The 'specularTint' property must be a vec3.");
					}
					
					material.specularTint = vec4(rgb.r, rgb.g, rgb.b, 1);
				} break;
				
				case "shininess": {
					float val;
					if (!lexer.consumeFloat(&val)) {
						lexer.error("The 'shininess' property must be a float.");
					}
					
					material.shininess = val;
				} break;

				case "shininessStrength": {
					float val;
					if (!lexer.consumeFloat(&val)) {
						lexer.error("The 'shininessStrength' property must be a float.");
					}
					
					material.shininessStrength = val;
				} break;

				case "ior": {
					float val;
					if (!lexer.consumeFloat(&val)) {
						lexer.error("The 'ior' property must be a float.");
					}
					
					material.ior = val;
				} break;

				case "opacity": {
					float val;
					if (!lexer.consumeFloat(&val)) {
						lexer.error("The 'opacity' property must be a float.");
					}
					
					material.opacity = val;
				} break;

				// ----

				default: {
					lexer.error("Unsupported material property: '{}'", ident);
				} break;
			}

			lexer.skipWhite();
		}
		
		if (lexer.eof) {
			lexer.error("End of file while parsing a material body.");
		}
		
		lexer.consume();		// eat the '}'
		return resultMatIdx;
	}


	void parseMaterialMap(LexerBase* lexer, Map* map) {
		lexer.skipWhite();
		if ('{' != lexer.peek()) {
			if (lexer.peek(0, 4) == "null") {
				lexer.consume(4);
				return;
			} else {
				lexer.error("Expected a map body. Got '{}'.", lexer.peek(0, 20));
			}
		} else {
			map.enabled = true;
		}

		lexer.consume();
		lexer.skipWhite();
		
		cstring mapName;
		cstring mapType;
		cstring mapFile;
		
		// TODO
		map.amount = 1.0f;
		
		while (lexer.peek() != '}' && !lexer.eof) {
			cstring ident;
			if (!lexer.consumeIdent(&ident)) {
				lexer.error("Expected an identifier.");
			}
			
			lexer.skipWhite();

			switch (ident) {
				case "name": {
					if (!lexer.consumeString((char c) {
						// TODO: mem
						mapName ~= c;
					})) {
						lexer.error("The 'name' property must be a string.");
					}
				} break;

				case "type": {
					if (!lexer.consumeString((char c) {
						// TODO: mem
						mapType ~= c;
					})) {
						lexer.error("The 'type' property must be a string.");
					}
				} break;
				
				case "file": {
					if (!lexer.consumeString((char c) {
						// TODO: mem
						mapFile ~= c;
					})) {
						lexer.error("The 'file' property must be a string.");
					}

					// TODO: mem
					cstring foo;
					xf.utils.Memory.alloc(foo, mapFile.length);
					foo[] = mapFile;
					map.bitmapPath = foo;
				} break;

				case "uvTile": {
					if (!lexer.consumeFloatArray((&map.uvTile.x)[0..2])) {
						lexer.error("The 'uvTile' property must be a vec2.");
					}
				} break;
				
				case "uvOffset": {
					if (!lexer.consumeFloatArray((&map.uvOffset.x)[0..2])) {
						lexer.error("The 'uvOffset' property must be a vec2.");
					}
				} break;

				default: {
					lexer.error("Unsupported material map property: '{}'", ident);
				} break;
			}

			lexer.skipWhite();
		}
		
		if (lexer.eof) {
			lexer.error("End of file while parsing a material map body.");
		}
		
		lexer.consume();		// eat the '}'
	}


	/+Animation loadAnimation(Array hme, Mesh mesh) {
		if (hme.hasChild(`physique`)) {
			assert (hme.hasChild(`mesh`));	// physique needs the original indices to vertex positions.
			
			return loadPhysique(hme.child(`physique`), hme.child(`mesh`), mesh);
		}
		
		return null;
	}
	
	
	SkeletalAnimation loadPhysique(Array physique, Array rawMesh, Mesh mesh) {
		hsfLog.trace("    physique {");
		
		auto res = new SkeletalAnimation;
		
		int numBones = physique.tupleLength(`bones`);
		res.allocBones(numBones);
		Bone[] bones = res.bones;
		
		hsfLog.trace("      {} bones", numBones);
		
		foreach (i, inout bone; bones) {
			{
				bone.name = physique.string_(`bones`, 0, i);
				bone.parentId = physique.int_(`boneParents`, 0, i);
			}
			
			
			{
				auto motion = physique.child(`boneMotion`, i);
				int numKeys = motion.count(`key`);
				
				bone.allocKeyframes(numKeys);
				
				foreach (keyi, inout key; bone.keyframes) {
					key.time = motion.float_(`key`, keyi);
					key.coordSys = loadCoordSys(motion.child(`key`, keyi, 1));
				}
			}
		}
		
		int numVerts = physique.int_(`weights`);
		assert (numVerts == physique.int_(`offsets`));
		res.allocVertices(numVerts);

		hsfLog.trace("      {} vertices", numVerts);
		
		double avgBonesPerVertex = 0.0;
		
		AnimVertex[]	vertices = res.vertices; {
			auto vWeights	= physique.child(`weights`, 0, 1);
			auto vOffsets		= physique.child(`offsets`, 0, 1);
			
			foreach (i, inout v; vertices) {
				int vbones = vWeights.tupleLength(i) / 2;				// they are [id weight] tuples
				assert (vbones == vOffsets.tupleLength(i) / 4);	// they are [id x y z] tuples
				
				v.allocBones(vbones);
				
				avgBonesPerVertex += cast(double)vbones / numVerts;
				
				for (int j = 0; j < vbones; ++j) {
					v.bones[j] = vWeights.int_(i, j*2);
					v.weights[j] = vWeights.float_(i, j*2+1);
					v.offsets[j] = vOffsets.vec3_(i, j*4+1);
				}
			}
		}
		
		hsfLog.trace("      {} bones/vertex avg",  avgBonesPerVertex);		
		hsfLog.trace("    }");
		
		physiqueDuplicateVertices(res, rawMesh, mesh);
		
		return res;
	}


	/**
		The reasoning behind this function is that the mesh loading process may duplicate some vertices in order to build a HW-friendly
		representation. The vertices in Physique on the other hand, correspond to the original positions. Solution: duplicate some physique vertices.
	*/
	private void physiqueDuplicateVertices(SkeletalAnimation anim, Array rawMesh, Mesh mesh) 
	in {
		assert (anim !is null);
		assert (mesh !is null);
	}
	out {
		assert (anim.vertices.length == mesh.positions.length);
	}
	body {
		vec3i[]	faces;
		scope (exit) faces.free();
		
		with (rawMesh.child(`faces`, 0, 1)) {
			int numFaces = count();
			faces.alloc(numFaces);
			vec3i_(faces);
		}
		
		AnimVertex[]	av;
		av.alloc(mesh.positions.length);
		
		foreach (vin, int vi; (cast(int*)faces.ptr)[0..faces.length*3]) {
			int newvi = mesh.indices[vin];
			av[newvi] = anim.vertices[vi].clone();
		}
		
		anim.overrideVertices_(av);
	}
	

	cstring translatePath(cstring filename) {
		/+ TODO
		if (std.file.isabs(filename)) return filename;
		else return std.path.join(hmeDir, filename);+/
		return filename;
	}
	
	
	cstring				hmeDir;
	Material[cstring]	materials;+/
}
