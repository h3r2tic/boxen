module xf.test.gfx.Common;

private {
	import xf.Common;
	import
		xf.gfx.Texture,
		xf.gfx.Buffer,
		xf.gfx.VertexBuffer,
		xf.gfx.UniformBuffer,
		xf.gfx.Mesh,
		xf.gfx.GPUEffect,
		xf.gfx.IRenderer;
	
	import
		xf.omg.core.LinearAlgebra,
		xf.omg.core.Misc,
		xf.omg.color.RGB,
		xf.omg.core.CoordSys;
		
	import
		assimp.api,
		assimp.postprocess,
		assimp.loader,
		assimp.scene,
		assimp.mesh,
		assimp.types,
		assimp.material,
		assimp.math;

	import xf.loader.scene.hsf.Hsf;

	import xf.loader.scene.model.all
		: LoaderNode = Node, LoaderMesh = Mesh, LoaderScene = Scene;
		
	import tango.io.Stdout;

	import Path = tango.io.Path;
	import Unicode = tango.text.Unicode;
}



float computeFresnelR0(float objectIoR, float volumeIoR = 1.0002926) {
	float c = objectIoR / volumeIoR;
	float R0 = (1 - c) / (1 + c);
	R0 *= R0;
	R0 *= 0.5f;
	float foo = (c * (1 + c) - c*c) / (c * (1 - c) + c*c);
	R0 *= (1 + foo * foo);
	return R0;
}


struct TextureMatcher {
	Texture delegate(cstring matName)		defaultTex;
	Texture delegate(cstring path)			loadTexture;
	
	// the handler will return true if the path works. then iteration can stop
	void delegate(bool delegate(cstring))	dirIter;
	
	
	private {
		alias Texture delegate(cstring, cstring, cstring) MatchFN;
		
		Texture tryDirect(cstring path, cstring name, cstring pathName) {
			//Stdout.formatln("tryDirect: '{}'", pathName);
			return loadTexture(pathName);
		}

		Texture tryCInsensitive(cstring path, cstring name, cstring pathName) {
			cstring nameLC = Unicode.toLower(name);
			foreach (ch; Path.children(path)) {
				if (Unicode.toLower(ch.name) == nameLC) {
					cstring fullPath = Path.join(ch.path, ch.name);
					//Stdout.formatln("tryCInsensitive: '{}'", fullPath);
					final tex = loadTexture(fullPath);
					if (tex.valid) {
						return tex;
					}
				}
			}
			return Texture.init;
		}

		Texture tryFuzzy(cstring path, cstring name, cstring pathName) {
			cstring best;
			int bestScore = 0;
			
			final wanted = Path.parse(Unicode.toLower(name));
			
			foreach (ch; Path.children(path)) {
				final p = Path.parse(Unicode.toLower(ch.name));
				if (p.ext == wanted.ext) {
					int score = 0;
					int maxL = min(p.name.length, wanted.name.length);
					for (int i = 0; i < maxL; ++i) {
						if (p.name[i] == wanted.name[i]) {
							++score;
						} else {
							break;
						}
					}
					
					if (score > bestScore) {
						bestScore = score;
						best = p.toString();
					}
				}
			}
			
			if (bestScore > 0) {
				cstring fullPath = Path.join(path, best);
				//Stdout.formatln("tryFuzzy: '{}'", fullPath);
				final tex = loadTexture(fullPath);
				if (tex.valid) {
					return tex;
				}
			}

			return Texture.init;
		}
	}
	
	Texture findTextureForMaterial(cstring material, cstring name, cstring rootPath) {
		name = Path.normalize(name);
		rootPath = Path.normalize(rootPath);
		
		assert (defaultTex !is null);
		assert (loadTexture !is null);
		Texture result;
		
		bool tryMethod(MatchFN loadTex) {
			if (result.valid) return true;
			//Stdout.formatln("tryMethod({})", name);
			
			bool tryPath(cstring path) {
				if (result.valid) return true;
				
				if (path is null) {
					path = name;
				} else if (Path.parse(path).isAbsolute) {
					path = Path.join(path, name);
				} else {
					path = Path.join(rootPath, path, name);
				}
				
				final p = Path.parse(path);
				result = loadTex(p.path, p.file, path);
				return result.valid;
			}
			
			if (dirIter is null || Path.parse(name).isAbsolute) {
				return tryPath(null);
			} else {
				bool found = false;
				dirIter((cstring path) {
					return found = tryPath(path);
				});
				return found;
			}
		}
		
		tryMethod(&tryDirect)
		|| tryMethod(&tryCInsensitive)
		|| tryMethod(&tryFuzzy);
		
		if (!result.valid && Path.parse(name).isAbsolute) {
			name = Path.parse(name).file;

			tryMethod(&tryDirect)
			|| tryMethod(&tryCInsensitive)
			|| tryMethod(&tryFuzzy);
		}

		return result;
	}
}



Mesh[] loadHsfModel(
		IRenderer renderer,
		GPUEffect effect,
		cstring path,
		ref UniformBuffer envUB,
		CoordSys modelCoordSys,
		TextureMatcher texMatcher,
		float scale = 1.0f,
		int numInstances = 1
) {
	path = Path.normalize(path);
	
	scope loader = new HsfLoader;
	loader.load(path);
	
	final scene = loader.scene;
	assert (scene !is null);
	assert (loader.meshes.length > 0);
	
	cstring modelFolder = Path.parse(path).path;
	
	assert (1 == scene.nodes.length);
	final root = scene.nodes[0];

	void iterAssetMeshes(void delegate(int, ref LoaderMesh) dg) {
		foreach (i, ref m; loader.meshes) {
			dg(i, m);
		}
	}
	
	int numMeshes = 0;
	iterAssetMeshes((int, ref LoaderMesh) {
		++numMeshes;
	});
	
	Mesh[] meshes = renderer.createMeshes(numMeshes);

	struct Vertex {
		vec3 pos;
		vec3 norm;
		vec3 tangent;
		vec3 bitangent;
		vec2 tc;
	}

	iterAssetMeshes((int meshIdx, ref LoaderMesh assetMesh) {
		assert (assetMesh.positions !is null);
		assert (assetMesh.normals !is null);
		
		// Initialize vertex data
		
		Vertex[] vertices;
		vertices.length = assetMesh.positions.length;

		final node = assetMesh.node;
		auto cs = node.localCS;
		
		foreach (i, ref v; vertices) {
			v.pos	= assetMesh.positions[i];
			v.pos	= cs.rotation.xform(v.pos);
			v.pos	+= vec3.from(cs.origin);
			v.pos	*= scale;
			assert (v.pos.ok);
			
			v.norm	= assetMesh.normals[i];
			v.norm	= cs.rotation.xform(v.norm);
			
			if (assetMesh.tangents.length) {
				final tangent = assetMesh.tangents[i];
				if (tangent.x <>= 0 && tangent.y <>= 0 && tangent.z <>= 0) {
					v.tangent = vec3.from(tangent);
				} else {
					v.tangent = vec3.unitX;
				}
			} else {
				v.tangent = vec3.unitX;
			}

			if (assetMesh.bitangents.length) {
				final bitangent = assetMesh.bitangents[i];
				if (bitangent.x <>= 0 && bitangent.y <>= 0 && bitangent.z <>= 0) {
					v.bitangent = vec3.from(bitangent);
				} else {
					v.bitangent = vec3.unitZ;
				}
			} else {
				v.bitangent = vec3.unitZ;
			}

			const int ch = 0;
			
			if (assetMesh.numTexCoordSets > ch) {
				v.tc = vec2.from(assetMesh.texCoords(ch).coords[i]);
			} else {
				v.tc = vec2.zero;
			}
		}

		auto vb = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			cast(void[])vertices
		);
		delete vertices;


		int objId = 0;
		void createObject(Mesh* mesh) {
			// Instantiate the effect and initialize its uniforms

			final efInst = renderer.instantiateEffect(effect);
			
			efInst.setUniform("lights[0].color",
				vec4(0.1f, 0.3f, 1.0f) * 1.0f
			);
			efInst.setUniform("lights[0].position",
				vec3(-3, 2, -5)
			);
			efInst.setUniform("lights[1].color",
				vec4(1.0f, 0.1f, 0.02f) * 2.f
			);
			efInst.setUniform("lights[2].color",
				vec4(1.0f, 1.0f, 1.0f) * 1.f
			);
			efInst.setUniform("lights[2].position",
				vec3(0, 2, 1)
			);
			
			
			Texture diffuseTex = Texture.init;
			Texture specularTex = Texture.init;

			vec2 diffuseTexTile = vec2.one;
			vec2 specularTexTile = vec2.one;
			
			vec4 diffuseTint = vec4.one;
			vec4 specularTint = vec4.one;
			
			float smoothness = 0.1f;
			float ior = 1.5f;
			
			if (auto material = assetMesh.material) {
				cstring path;
				
				ior = material.ior;
				
				enum {
					DiffuseIdx = 1,
					SpecularIdx = 2
				}
				
				if (auto map = material.getMap(DiffuseIdx)) {
					diffuseTex = texMatcher.findTextureForMaterial(
						"diffuse",
						map.bitmapPath,
						modelFolder
					);
					diffuseTexTile = map.uvTile;
				}

				if (auto map = material.getMap(SpecularIdx)) {
					specularTex = texMatcher.findTextureForMaterial(
						"specular",
						map.bitmapPath,
						modelFolder
					);
					specularTexTile = map.uvTile;
				}
				
				smoothness = material.shininess;
				if (smoothness > 0.99f) {
					smoothness = 0.99f;
				}
				
				convertRGB
					!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)
					(material.diffuseTint, &diffuseTint);

				convertRGB
					!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)
					(material.specularTint, &specularTint);
			}

			efInst.setUniform("FragmentProgram.smoothness", smoothness);
			efInst.setUniform("FragmentProgram.diffuseTint", diffuseTint);
			efInst.setUniform("FragmentProgram.specularTint", specularTint);
			

			if (!diffuseTex.valid) {
				diffuseTex = texMatcher.defaultTex("diffuse");
			}

			if (!specularTex.valid) {
				specularTex = texMatcher.defaultTex("specular");
			}
			
			efInst.setUniform("FragmentProgram.diffuseTex",
				diffuseTex
			);
			efInst.setUniform("FragmentProgram.diffuseTexTile",
				diffuseTexTile
			);

			efInst.setUniform("FragmentProgram.specularTex",
				specularTex
			);
			efInst.setUniform("FragmentProgram.specularTexTile",
				specularTexTile
			);
			
			efInst.setUniform("FragmentProgram.fresnelR0",
				computeFresnelR0(ior)
			);

			// Create a vertex buffer and bind it to the shader

			efInst.setVarying(
				"VertexProgram.input.position",
				vb,
				VertexAttrib(
					Vertex.init.pos.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);

			efInst.setVarying(
				"VertexProgram.input.normal",
				vb,
				VertexAttrib(
					Vertex.init.norm.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);
						
			efInst.setVarying(
				"VertexProgram.input.tangent",
				vb,
				VertexAttrib(
					Vertex.init.tangent.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);

			efInst.setVarying(
				"VertexProgram.input.bitangent",
				vb,
				VertexAttrib(
					Vertex.init.bitangent.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);

			efInst.setVarying(
				"VertexProgram.input.texCoord",
				vb,
				VertexAttrib(
					Vertex.init.tc.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec2
				)
			);

			// Create a uniform buffer for the environment and bind it to the effect
			
			if (!envUB.valid) {
				final envUBData = &effect.uniformBuffers[0];
				final envUBSize = envUBData.totalSize;
				
				envUB = renderer.createUniformBuffer(
					BufferUsage.StaticDraw,
					envUBSize,
					null
				);
				
				// Initialize the uniform buffer
				
				envUB.mapRange(
					0,
					envUBSize,
					BufferAccess.Write | BufferAccess.InvalidateBuffer,
					(void[] data) {
						*cast(vec4*)(
							data.ptr + envUBData.params.dataSlice[
								envUBData.getUniformIndex("envData.ambientColor")
							].offset
						) = vec4.zero;//vec4(0.001, 0.001, 0.001, 1);

						*cast(float*)(
							data.ptr + envUBData.params.dataSlice[
								envUBData.getUniformIndex("envData.lightScale")
							].offset
						) = 50.0f;
					}
				);

				effect.bindUniformBuffer(0, *envUB.asBuffer);
			}
			
			// Create and set the index buffer

			mesh.numIndices = assetMesh.indices.length;
			// assert (indices.length > 0 && indices.length % 3 == 0);
			
			uword minIdx = uword.max;
			uword maxIdx = uword.min;
			
			foreach (i; assetMesh.indices) {
				if (i < minIdx) minIdx = i;
				if (i > maxIdx) maxIdx = i;
			}

			mesh.minIndex = minIdx;
			mesh.maxIndex = maxIdx;
			
			(mesh.indexBuffer = renderer.createIndexBuffer(
				BufferUsage.StaticDraw,
				assetMesh.indices
			)).dispose();
			
			// Finalize the mesh
			
			mesh.effectInstance = efInst;
			mesh.numInstances = numInstances;
		}
		
		auto mesh = &meshes[meshIdx];
		createObject(mesh);
		mesh.modelToWorld = modelCoordSys;
	});
	
	scene.dispose();	
	return meshes;
}


Mesh[] loadModel(
		IRenderer renderer,
		GPUEffect effect,
		cstring path,
		ref UniformBuffer envUB,
		CoordSys modelCoordSys,
		TextureMatcher texMatcher,
		float scale = 1.0f,
		int numInstances = 1
) {
	Assimp.load(Assimp.LibType.Release);

	final scene = aiImportFile(
		toStringz(path),
		(AI_PROCESS_PRESET_TARGET_REALTIME_QUALITY |
		aiPostProcessSteps.PreTransformVertices |
		aiPostProcessSteps.OptimizeMeshes |
		aiPostProcessSteps.OptimizeGraph /+|
		aiPostProcessSteps.FixInfacingNormals+/)
		& ~aiPostProcessSteps.SplitLargeMeshes
	);
	
	final err = aiGetErrorString();
	if (scene is null) {
		Stdout.formatln("assImp error: {}", fromStringz(err));
	}
	
	assert (scene !is null);
	assert (scene.mNumMeshes > 0);
	
	cstring modelFolder = Path.parse(path).path;
	
	final root = scene.mRootNode;

	void iterAssetMeshes(void delegate(int, aiMesh*) dg) {
		int meshI = 0;
		
		void recurse(aiNode* node) {
			foreach (assetMeshIdx; node.mMeshes[0..node.mNumMeshes]) {
				final assetMesh = scene.mMeshes[assetMeshIdx];

				bool hasTris = false;
				foreach (ref face; assetMesh.mFaces[0 .. assetMesh.mNumFaces]) {
					if (3 == face.mNumIndices) {
						hasTris = true;
						break;
					}
				}
				
				if (hasTris) {
					dg(meshI++, assetMesh);
				}
			}
			
			foreach (ch; node.mChildren[0..node.mNumChildren]) {
				recurse(ch);
			}
		}
		
		recurse(root);
	}
	
	int numMeshes = 0;
	iterAssetMeshes((int, aiMesh*) {
		++numMeshes;
	});
	
	Mesh[] meshes = renderer.createMeshes(numMeshes);

	struct Vertex {
		vec3 pos;
		vec3 norm;
		vec3 tangent;
		vec3 bitangent;
		vec2 tc;
	}

	iterAssetMeshes((int meshIdx, aiMesh* assetMesh) {
		assert (assetMesh.mVertices !is null);
		assert (assetMesh.mNormals !is null);
		
		// Initialize vertex data
		
		Vertex[] vertices;
		vertices.length = assetMesh.mNumVertices;
		
		foreach (i, ref v; vertices) {
			v.pos = vec3.from(assetMesh.mVertices[i]) * scale;
			
			final norm = assetMesh.mNormals[i];
			if (norm.x <>= 0 && norm.y <>= 0 && norm.z <>= 0) {
				v.norm = vec3.from(norm);
			} else {
				v.norm = vec3.unitY;
			}
			
			if (assetMesh.mTangents) {
				final tangent = assetMesh.mTangents[i];
				if (tangent.x <>= 0 && tangent.y <>= 0 && tangent.z <>= 0) {
					v.tangent = vec3.from(tangent);
				} else {
					v.tangent = vec3.unitX;
				}
			} else {
				v.tangent = vec3.unitX;
			}

			if (assetMesh.mBitangents) {
				final bitangent = assetMesh.mBitangents[i];
				if (bitangent.x <>= 0 && bitangent.y <>= 0 && bitangent.z <>= 0) {
					v.bitangent = vec3.from(bitangent);
				} else {
					v.bitangent = vec3.unitZ;
				}
			} else {
				v.bitangent = vec3.unitZ;
			}

			const int ch = 0;
			
			if (assetMesh.mTextureCoords[ch]) {
				v.tc = vec2.from(assetMesh.mTextureCoords[ch][i]);
			} else {
				v.tc = vec2.zero;
			}
		}

		auto vb = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			cast(void[])vertices
		);
		delete vertices;


		int objId = 0;
		void createObject(Mesh* mesh) {
			// Instantiate the effect and initialize its uniforms

			final efInst = renderer.instantiateEffect(effect);
			
			efInst.setUniform("lights[0].color",
				vec4(0.1f, 0.3f, 1.0f) * 1.0f
			);
			efInst.setUniform("lights[0].position",
				vec3(-3, 2, -5)
			);
			efInst.setUniform("lights[1].color",
				vec4(1.0f, 0.1f, 0.02f) * 2.f
			);
			efInst.setUniform("lights[2].color",
				vec4(1.0f, 1.0f, 1.0f) * 1.f
			);
			efInst.setUniform("lights[2].position",
				vec3(0, 2, 1)
			);
			
			
			Texture diffuseTex = Texture.init;
			Texture specularTex = Texture.init;
			
			vec2 diffuseTexTile = vec2.one;
			vec2 specularTexTile = vec2.one;

			vec4 diffuseTint = vec4.one;
			vec4 specularTint = vec4.one;
			
			float smoothness = 0.1f;
			float ior = 1.5f;
			
			if (scene.mMaterials) {
				final material = scene.mMaterials[assetMesh.mMaterialIndex];
				aiString path;
				
				if (aiReturn.SUCCESS == aiGetMaterialString(
					material,
					AI_MATKEY_TEXTURE,
					aiTextureType.DIFFUSE,
					0,
					&path
				)) {
					diffuseTex = texMatcher.findTextureForMaterial(
						"diffuse",
						path.data[0..path.length],
						modelFolder
					);
				}

				if (aiReturn.SUCCESS == aiGetMaterialString(
					material,
					AI_MATKEY_TEXTURE,
					aiTextureType.SPECULAR,
					0,
					&path
				)) {
					Stdout.formatln("***specular == {}", path.data[0..path.length]);
					
					specularTex = texMatcher.findTextureForMaterial(
						"specular",
						path.data[0..path.length],
						modelFolder
					);
				}

				if (aiReturn.SUCCESS == aiGetMaterialFloat(
					material,
					AI_MATKEY_SHININESS,
					0,
					0,
					&smoothness,
					null
				)) {
					smoothness /= 90.f;
					if (smoothness > 0.99f) {
						smoothness = 0.99f;
					}
					//Stdout.formatln("Yay, got smoothness == {}", smoothness);
				}

				aiGetMaterialColor(
					material,
					AI_MATKEY_COLOR_DIFFUSE,
					0,
					0,
					cast(aiColor4D*)&diffuseTint
				);

				convertRGB
					!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)
					(diffuseTint, &diffuseTint);
				

				/+aiGetMaterialColor(
					material,
					AI_MATKEY_COLOR_SPECULAR,
					0,
					0,
					cast(aiColor4D*)&specularTint
				);
				specularTint = sRGB_to_RGB(specularTint);+/
			}

			efInst.setUniform("FragmentProgram.smoothness", smoothness);
			efInst.setUniform("FragmentProgram.diffuseTint", diffuseTint);
			efInst.setUniform("FragmentProgram.specularTint", specularTint);
			

			if (!diffuseTex.valid) {
				diffuseTex = texMatcher.defaultTex("diffuse");
			}

			if (!specularTex.valid) {
				specularTex = texMatcher.defaultTex("specular");
			}
			
			efInst.setUniform("FragmentProgram.diffuseTex",
				diffuseTex
			);
			efInst.setUniform("FragmentProgram.diffuseTexTile",
				diffuseTexTile
			);

			efInst.setUniform("FragmentProgram.specularTex",
				specularTex
			);
			efInst.setUniform("FragmentProgram.specularTexTile",
				specularTexTile
			);
			
			efInst.setUniform("FragmentProgram.fresnelR0",
				computeFresnelR0(ior)
			);


			// Create a vertex buffer and bind it to the shader

			efInst.setVarying(
				"VertexProgram.input.position",
				vb,
				VertexAttrib(
					Vertex.init.pos.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);

			efInst.setVarying(
				"VertexProgram.input.normal",
				vb,
				VertexAttrib(
					Vertex.init.norm.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);
						
			efInst.setVarying(
				"VertexProgram.input.tangent",
				vb,
				VertexAttrib(
					Vertex.init.tangent.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);

			efInst.setVarying(
				"VertexProgram.input.bitangent",
				vb,
				VertexAttrib(
					Vertex.init.bitangent.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec3
				)
			);

			efInst.setVarying(
				"VertexProgram.input.texCoord",
				vb,
				VertexAttrib(
					Vertex.init.tc.offsetof,
					Vertex.sizeof,
					VertexAttrib.Type.Vec2
				)
			);

			// Create a uniform buffer for the environment and bind it to the effect
			
			if (!envUB.valid) {
				final envUBData = &effect.uniformBuffers[0];
				final envUBSize = envUBData.totalSize;
				
				envUB = renderer.createUniformBuffer(
					BufferUsage.StaticDraw,
					envUBSize,
					null
				);
				
				// Initialize the uniform buffer
				
				envUB.mapRange(
					0,
					envUBSize,
					BufferAccess.Write | BufferAccess.InvalidateBuffer,
					(void[] data) {
						*cast(vec4*)(
							data.ptr + envUBData.params.dataSlice[
								envUBData.getUniformIndex("envData.ambientColor")
							].offset
						) = vec4.zero;//vec4(0.001, 0.001, 0.001, 1);

						*cast(float*)(
							data.ptr + envUBData.params.dataSlice[
								envUBData.getUniformIndex("envData.lightScale")
							].offset
						) = 50.0f;
					}
				);

				effect.bindUniformBuffer(0, *envUB.asBuffer);
			}
			
			// Create and set the index buffer
			
			uword[] indices;
			foreach (ref face; assetMesh.mFaces[0 .. assetMesh.mNumFaces]) {
				if (3 == face.mNumIndices) {
					indices ~= face.mIndices[0..3];
				}
			}
			
			mesh.numIndices = indices.length;
			// assert (indices.length > 0 && indices.length % 3 == 0);
			
			uword minIdx = uword.max;
			uword maxIdx = uword.min;
			
			foreach (i; indices) {
				if (i < minIdx) minIdx = i;
				if (i > maxIdx) maxIdx = i;
			}

			mesh.minIndex = minIdx;
			mesh.maxIndex = maxIdx;
			
			(mesh.indexBuffer = renderer.createIndexBuffer(
				BufferUsage.StaticDraw,
				indices
			)).dispose();
			
			// Finalize the mesh
			
			mesh.effectInstance = efInst;
			mesh.numInstances = numInstances;
		}
		
		auto mesh = &meshes[meshIdx];
		createObject(mesh);
		mesh.modelToWorld = modelCoordSys;
	});
	
	return meshes;
}
