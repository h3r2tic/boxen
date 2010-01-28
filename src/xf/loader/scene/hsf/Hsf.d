module xf.loader.scene.hsf.Hsf;

private {
	import xf.Common;
	
	import
		xf.loader.scene.model.all,
		xf.loader.scene.hsf.Log;
		
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
		
		foreach (ref mesh; meshes) {
			computeExtraMeshData(mesh);
		}
	}
	
	void computeExtraMeshData(ref Mesh mesh) {
		if (
			mesh._normals.length > mesh._tangents.length
		&&	mesh._texCoords.length > 0
		&&	mesh._texCoords[0].length > 0
		) {
			mesh.allocTangents(mesh._normals.length);
			mesh.allocBitangents(mesh._normals.length);
			
			hsfLog.trace("Calculating tangents and bitangents.");
			computeMeshTangents ( 
				mesh._indices,
				mesh._positions,
				mesh._normals,
				mesh._texCoords[0],
				mesh._tangents,
				mesh._bitangents
			);
		}
	}
	
	
	float	scale = 1.f;
	Scene	scene;
	
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
				} break;

				case "indices": {
					if (!lexer.consumeInt(&numIndices)) {
						lexer.error("The 'indices' property must be an integer array.");
					}
					
					for (int i = 0; i < numIndices; ++i) {
						lexer.skipWhite;
						
						int idx;
						if (!lexer.consumeInt(&idx)) {
							lexer.error("Syntax error in the indices array.");
						}
						
						// TODO: add the index somewhere
					}
				} break;

				case "faceSubMats": {
					int numFaces_;
					if (!lexer.consumeInt(&numFaces_)) {
						lexer.error("The 'faceSubMats' property must be an integer array.");
					}
					
					for (int i = 0; i < numFaces_; ++i) {
						lexer.skipWhite;
						
						int matIdx;
						if (!lexer.consumeInt(&matIdx)) {
							lexer.error("Syntax error in the submaterial index array.");
						}
						
						// TODO: add the index somewhere
					}
				} break;

				case "positions": {
					if (!lexer.consumeInt(&numPositions)) {
						lexer.error("The 'positions' property must be a vec3 hex array.");
					}
					
					lexer.skipWhite;

					for (int i = 0; i < numPositions; ++i) {
						vec3 pos;
						if (!lexer.readHexData(cast(u32[])(&pos)[0..1])) {
							lexer.error("Syntax error in the position array.");
						}
						
						// TODO: add the position somewhere
					}
				} break;

				case "normals": {
					int numNormals;
					
					if (!lexer.consumeInt(&numNormals)) {
						lexer.error("The 'normals' property must be a vec3 hex array.");
					}
					
					lexer.skipWhite;

					for (int i = 0; i < numNormals; ++i) {
						vec3 norm;
						if (!lexer.readHexData(cast(u32[])(&norm)[0..1])) {
							lexer.error("Syntax error in the normals array.");
						}
						
						// TODO: add the normal somewhere
					}
				} break;

				case "maps": {
					if (!lexer.consumeInt(&numMaps)) {
						lexer.error("The 'maps' property must be a struct array.");
					}
					
					for (int i = 0; i < numMaps; ++i) {
						parseMeshMapCoords(lexer);
						
						// TODO: add the coords somewhere
					}
				} break;
				
				default: {
					lexer.error("Unsupported mesh property: '{}'", ident);
				} break;
			}

			lexer.skipWhite();
		}
		
		if (lexer.eof) {
			lexer.error("End of file while parsing a node body.");
		}
		
		lexer.consume();		// eat the '}'
	}


	void parseMeshMapCoords(LexerBase* lexer) {
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
				} break;

				case "indices": {
					if (!lexer.consumeInt(&numIndices)) {
						lexer.error("The 'indices' property must be an integer array.");
					}
					
					for (int i = 0; i < numIndices; ++i) {
						lexer.skipWhite;
						
						int idx;
						if (!lexer.consumeInt(&idx)) {
							lexer.error("Syntax error in the indices array.");
						}
						
						// TODO: add the index somewhere
					}
				} break;

				case "coords": {
					if (!lexer.consumeInt(&numCoords)) {
						lexer.error("The 'coords' property must be a vec2 hex array.");
					}
					
					lexer.skipWhite;

					for (int i = 0; i < numCoords; ++i) {
						vec2 uv;
						if (!lexer.readHexData(cast(u32[])(&uv)[0..1])) {
							lexer.error("Syntax error in the coords array.");
						}
						
						// TODO: add the coord somewhere
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
		vec3	scale = vec3.one;
		
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

				case "scale": {
					if (!lexer.readHexData(cast(u32[])(&scale)[0..1])) {
						lexer.error("The 'scale' property must be a hex vec3.");
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
					vec3fi.from(translation * scale),
					quat.axisRotation(axis, -rotation.a)
				);
			} else {
				cs = CoordSys(
					vec3fi.from(translation * scale),
					quat.identity
				);
			}
		}
		
		node.setTransform(cs);

		if (parent != -1) {
			assert (parent < nodeIdx);
			node.parent = nodes[parent];
		}
		
		if (lexer.eof) {
			lexer.error("End of file while parsing a node body.");
		}
		
		lexer.consume();		// eat the '}'
	}
	
	
	Mesh[]	meshes;
	Node[]	nodes;


	/+Node loadNodeTree(Array hme) {
		Node n = loadNode(hme);
		
		for (int i = 0; i < hme.count(`node`); ++i) {
			auto ch = loadNodeTree(hme.child(`node`, i));
			auto cs = ch.localCS;
			n.attachChild(ch);
			ch.setTransform(cs, n.localCS);
		}
		
		return n;
	}
	
	
	// BUG: colors can't have alpha channels with the way Hme currently works.
	void loadNodeMesh(Mesh mesh, Array hme, vec3 meshScale) {
		with (hme) {
			vec3[] vertices;
			scope (exit) vertices.free();

			with (child(`verts`, 0, 1)) {
				int numVerts = count();
				hsfLog.trace("    {} vertices", numVerts);
				
				vertices.alloc(numVerts);
				vec3_(vertices);
				
				foreach (inout v; vertices) {
					v *= scale;
					v.x *= meshScale.x;
					v.y *= meshScale.y;
					v.z *= meshScale.z;
				}
			}
			
			
			vec3i[]	faces;
			scope (exit) faces.free();
			
			vec3[]	normals;
			scope (exit) normals.free();
			

			with (child(`faces`, 0, 1)) {
				int numFaces = count();
				hsfLog.trace("    {} faces", numFaces);
	
				faces.alloc(numFaces);
				vec3i_(faces);
			}

			with (child(`faceVertexNormals`)) {
				normals.alloc(faces.length * 3);
				vec3_(normals);
			}

			
			uint[] indices = (cast(uint*)faces.ptr)[0 .. faces.length * 3];
			foreach (i; indices) assert (i < vertices.length);

			
			uint[]	normalIndices;
			scope (exit) normalIndices.free();
			
			{
				scope	normalHash = new HashMap!(QuantizedNormal, uint, Container.hash, Container.reap, Container.Chunk);
				uint		numNormals = 0;
				
				normalIndices.alloc(indices.length);
				
				vec3[]	quantizedNormals;
				quantizedNormals.alloc(indices.length);
				
				foreach (int ni, vec3 n; normals) {
					QuantizedNormal qn = QuantizedNormal(n);
					uint* fnd = qn in normalHash;
					
					if (fnd !is null) {
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
					float error = (normals[i] - quantizedNormals[ni]).length;
					if (error > maxError) maxError = error;
				}
				
				normals.free();
				normals = quantizedNormals;
			}
			
			
			assert (normalIndices.length == indices.length);
			
			
			int numMaps = int_(`maps`);
			hsfLog.trace("    {} maps", numMaps);
			
			
			vec3[][]	texCoords;
			uint[][]		texCoordIndices;
			texCoords.alloc(numMaps);
			texCoordIndices.alloc(numMaps);

			scope (exit) {
				foreach (ref tci; texCoordIndices) {
					tci.free();
				}
				texCoordIndices.free();

				foreach (ref tc; texCoords) {
					tc.free();
				}
				texCoords.free();
			}
			
			
			uint numNonEmptyMaps = 0;
			
			for (int mapId = 0; mapId < numMaps; ++mapId)  {
				if (hasChild(`map`, mapId)) with (child(`map`, mapId)) {
					++numNonEmptyMaps;
					
					hsfLog.trace("    {} map", mapId);
					with (child(`verts`, 0, 1)) {
						int numVerts = count();
						hsfLog.trace("      {} vertices", numVerts);

						texCoords[mapId].alloc(numVerts);
						vec3_(texCoords[mapId]);
					}
					
					
					with (child(`faces`, 0, 1)) {
						int numFaces = count();
						hsfLog.trace("      {} faces", numFaces);

						assert (numFaces == faces.length);
						
						texCoordIndices[mapId].alloc(numFaces * 3);
						vec3i_((cast(vec3i*)texCoordIndices[mapId].ptr)[0 .. numFaces]);
					}
				} else {
					hsfLog.trace("    map {} is empty", mapId);
					assert (texCoords[mapId] is null);		// sanity check. we will use this property later
				}
			}

			
			// now fix indices
			
			uint[][]	propertyIndices;
			
			propertyIndices.alloc(2 + numNonEmptyMaps);
			scope (exit) propertyIndices.free();
			
			propertyIndices[0] = indices;
			propertyIndices[1] = normalIndices;
			
			// find non-empty index lists and put them to the propertyIndex array
			{
				uint dst = 0;
				for (int mapId = 0; mapId < numMaps; ++mapId)  {
					if (texCoords[mapId] !is null) {
						propertyIndices[2+dst] = texCoordIndices[mapId];
						++dst;
					}
				}
				assert (dst == numNonEmptyMaps);
			}
			
			mesh.allocIndices(indices.length);
			uint[] finalIndices = mesh.indices();

			remapIndices(propertyIndices, finalIndices);
			uint maxIndex = 0; {
				foreach (i; finalIndices) if (i > maxIndex) maxIndex = i;
			}
			
			hsfLog.trace("    {} unique vertices", maxIndex+1);

			mesh.allocPositions(maxIndex+1);
			vec3[] positions = mesh.positions();
			
			mesh.allocNormals(maxIndex+1);
			vec3[] vnormals = mesh.normals();

			if (texCoords.length > 0 && texCoords[0] !is null) {
				mesh.allocColors(maxIndex+1);
				vec4[] colors = mesh.colors();

				foreach (src, dst; finalIndices) {
					vec3 v = texCoords[0][texCoordIndices[0][src]];
					colors[dst] = vec4(v.r, v.g, v.b, 1);
				}
			}
			
			foreach (src, dst; finalIndices) {
				vec3 v = vertices[indices[src]];
				positions[dst] = v;

				vec3 n = normals[normalIndices[src]];
				vnormals[dst] = n;
			}

			if (texCoords.length > 1) {
				foreach (ti, t; texCoords[1..$]) {
					if (t !is null) {
						mesh.allocTexCoords(ti, maxIndex+1);
						vec3[] coords = mesh.texCoords(ti);
						foreach (src, dst; finalIndices) {
							vec3 v = t[texCoordIndices[ti+1][src]];
							coords[dst] = v;
						}
					}
				}
			}
		}
	}
	
	
	void remapIndices(uint[][] propertyIndices, uint[] finalIndices)
	in {
		assert (finalIndices.length > 0);
		
		foreach (pi; propertyIndices) {
			assert (pi.length == finalIndices.length);
		}
	}
	out {
		// to be written
	}
	body {
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
	
	
	void remapIndicesWorker(uint[] srcA, uint[] srcB, uint[] dst)
	in {
		assert (srcA.length == srcB.length);
		assert (srcB.length == dst.length);
		assert (srcA !is srcB && srcA !is dst && srcB !is dst);
	}
	body {
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
	
	
	CoordSys loadCoordSys(Array hme) {
		vec4 v = hme.vec4_(`rot`);
		quat q = quat(v.x, -v.z, v.y, v.w);
		vec3 axis;
		real angle;

		q.getAxisAngle(axis, angle);
		
		axis.normalize();
		
		return CoordSys(vec3fi.from(hme.vec3_(`pos`) * scale), quat.axisRotation(vec3(axis.x, axis.z, -axis.y), -angle));
	}
	
	
	Node loadNode(Array hme) {
		Node node = new Node;

		node.name = hme.string_(`name`);
		node.type = hme.string_(`type`);

		hsfLog.trace("    node {} ({})", node.name, node.type);

		vec3 meshScale = vec3(1, 1, 1);
		CoordSys meshCS = CoordSys.identity;
		
		if (hme.hasChild(`transform`)) with (hme.child(`transform`)) {
			node.setTransform(loadCoordSys(hme.child(`transform`)));
			meshScale = vec3_(`scl`);
			/+rgNode.position			= vec3fi.init.convert(vec3_(`pos`));		// BUG: precission loss	// .init is used to sidestep a bug in dmd.172
			rgNode.rotation.xyzw	= vec4_(`rot`);
			rgNode.scale				= vec3_(`scl`);+/
		}

		
		Mesh firstMesh;
		
		if (hme.hasChild(`mesh`)) {
			Mesh mesh = new Mesh;
			loadNodeMesh(mesh, hme.child(`mesh`), meshScale);
			
			//node.meshes ~= mesh;
			node.attachChild(mesh);
			if (firstMesh is null) {
				firstMesh = mesh;
			}

			cstring materialName = "undefined";
			
			if (hme.hasField(`material`)) materialName = hme.string_(`material`);
			hsfLog.trace("    material {}", materialName);
		
			if (materialName != "undefined" && materialName in materials) {
				mesh.material = materials[materialName];
			}
		}

		node.animation = loadAnimation(hme, firstMesh);
		
		int childCount = hme.int_(`children`);
		hsfLog.trace("    {} children", childCount);
		
		return node;
	}
	
	
	Animation loadAnimation(Array hme, Mesh mesh) {
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
