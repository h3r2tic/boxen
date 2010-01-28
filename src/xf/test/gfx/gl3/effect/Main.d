module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.utils.SimpleCamera,
	
	assimp.api,
	assimp.postprocess,
	assimp.loader,
	assimp.scene,
	assimp.mesh,
	assimp.types,
	assimp.material,
	assimp.math,
	
	xf.loader.scene.hsf.Hsf,

	xf.img.Image,
	xf.img.FreeImageLoader,
	
	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	xf.omg.core.Misc,
	tango.io.Stdout,
	tango.time.StopWatch;

	

UniformBuffer envUB;


void main() {
	final ldr = new HsfLoader;
	ldr.load(`C:\Users\h3r3tic\Documents\3dsMax\export\foo.hsf`);
	ldr.scene.dispose();
	//(new TestApp).run;
}


class TestApp : GfxApp {
	GPUEffect			effect;
	Mesh[]				meshes;
	MeshRenderData*[]	renderList;
	float				lightRot = 0.0f;
	float				lightPulse = 0.0f;
	StopWatch			timer;
	SimpleCamera		camera;

	this() {
		this.windowTitle = "Effect test";
		Assimp.load(Assimp.LibType.Release);
	}
	
	override void initialize() {
		camera = new SimpleCamera(vec3.zero, 0.0f, 0.0f, inputHub.mainChannel);
		window.interceptCursor = true;
		window.showCursor = false;
		
		use (window) in (GL gl) {
			gl.Enable(DEPTH_TEST);
			gl.Enable(CULL_FACE);
			gl.ClearColor(0.1f, 0.1f, 0.1f, 0.0f);

			// Create the effect from a cgfx file
			
			effect = renderer.createEffect(
				"sample",
				EffectSource.filePath("sample.cgfx")
			);
			
			// Specialize the shader template with 2 lights
			// - an ambient and a point light

			effect.useGeometryProgram = false;
			effect.setArraySize("lights", 3);
			effect.setUniformType("lights[0]", "PointLight");
			effect.setUniformType("lights[1]", "PointLight");
			effect.setUniformType("lights[2]", "PointLight");
			effect.compile();
			
			// ---- Some debug info printing ----
			{
				with (*effect.uniformParams()) {
					Stdout.formatln("Effect uniforms:");
					for (int i = 0; i < params.length; ++i) {
						Stdout.formatln("\t{}", params.name[i]);
					}
				}

				Stdout.formatln("Effect varyings:");
				for (int i = 0; i < effect.varyingParams.length; ++i) {
					Stdout.formatln("\t{}", effect.varyingParams.name[i]);
				}
			}


			scope imgLoader = new FreeImageLoader;

			version (Demo) {
				const cstring mediaDir = `media/`;
			} else {
				const cstring mediaDir = `../../../media/`;
			}

			/+final img2 = imgLoader.load(mediaDir~"img/Walk_Of_Fame/Mans_Outside_2k.hdr");
			assert (img2.valid);
			TextureRequest req;
			req.internalFormat = TextureInternalFormat.RGBA_FLOAT16;
			final tex2 = renderer.createTexture(img2, req);
			assert (tex2.valid);+/

			final testgrid = renderer.createTexture(
				imgLoader.load(mediaDir~"img/testgrid.png")
			);
			assert (testgrid.valid);

			final whiteTexture = renderer.createTexture(
				imgLoader.load(mediaDir~"img/white.bmp")
			);
			assert (whiteTexture.valid);
			
			
			auto tm = TextureMatcher(
				(cstring matName) {
					switch (matName) {
						case "diffuse": return whiteTexture;
						case "specular": return whiteTexture;
						default: return testgrid;
					}					
				},
				(cstring path) {
					if (Path.exists(path)) {
						final img = imgLoader.load(path);
						if (img.valid) {
							return renderer.createTexture(img);
						}
					}
					return Texture.init;
				},
				(bool delegate(cstring) dg) {
					if (dg("tex")) return;
					if (dg(".")) return;
				}
			);		

			meshes ~= loadModel(
				renderer,
				effect,
				mediaDir~`mesh/MTree/MonsterTree.3ds`,
				CoordSys(vec3fi[1.5, -1, -1.5]),
				tm,
				0.01f
			);
			
			meshes ~= loadModel(
				renderer,
				effect,
				mediaDir~`mesh/cia2/cia.obj`,
				CoordSys(vec3fi[0, -1, -0.5]),
				tm,
				0.01f
			);
			
			/+meshes ~= loadModel(
				renderer,
				effect,
				mediaDir~`mesh/cia2/cia2.obj`,
				CoordSys(vec3fi[-2, -1, -1.5]),
				tm,
				0.01f
			);+/

			if (0 == meshes.length) {
				throw new Exception("No meshes in the scene :(");
			} else {
				uword numTris = 0;
				uword numMeshes = 0;
				
				foreach (m; meshes) {
					numTris += m.getNumInstances * m.getNumIndices / 3;
					numMeshes += m.getNumInstances;
				}
				
				Stdout.formatln(
					"{} Meshes with a total of {} triangles in the scene.",
					numMeshes,
					numTris
				);
			}

			effect.setUniform("viewToClip",
				mat4.perspective(
					65.0f,		// fov
					cast(float)window.width / window.height,	// aspect
					0.1f,		// near
					100.0f		// far
				)
			);
			
			foreach (ref m; meshes) {
				renderList ~= m.renderData;
			}
			
			timer.start();
		};
	}
	
	
	void render(GL gl) {
		final timeDelta = timer.stop();
		timer.start();

		effect.setUniform("worldToView",
			camera.getMatrix
		);
		
		lightRot += timeDelta * 90.f;
		lightPulse += timeDelta * 10.f;

		// update the shared environment params
		{
			final envUBData = &effect.uniformBuffers[0];
			
			/+size_t lightScaleOffset = envUBData.params.dataSlice[
				envUBData.getUniformIndex("envData.lightScale")
			].offset;+/

			final eyePosSlice = envUBData.params.dataSlice[
				envUBData.getUniformIndex("envData.eyePos")
			];
			
			
			/+float lightScale = (cos(deg2rad * lightPulse) + 1.f) * 15.0f;
			envUB.setSubData(lightScaleOffset, cast(void[])(&lightScale)[0..1]);+/
			
			
			if (eyePosSlice.length > 0) {
				vec3 eyePos = camera.position;
				envUB.setSubData(eyePosSlice.offset, cast(void[])(&eyePos)[0..1]);
			}
		}

		// update light positions
		foreach (mesh; renderList) {
			mesh.effectInstance.setUniform("lights[1].position",
				vec3(0, 0, -4) + quat.yRotation(lightRot).xform(vec3(5, 2, 0))
			);
		}

		gl.Clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
		
		foreach (i, ref m; meshes) {
			if (m.worldMatricesDirty) {
				auto rd = m.renderData;
				auto cs = m.modelToWorld;
				rd.modelToWorld = cs.toMatrix34;
				cs.invert;
				rd.worldToModel = cs.toMatrix34;
			}
		}
		
		renderer.render(renderList);
	}
}

import Path = tango.io.Path;
import Unicode = tango.text.Unicode;


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
				Stdout.formatln("tryFuzzy: '{}'", fullPath);
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
			Stdout.formatln("tryMethod({})", name);
			
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


Mesh[] loadModel(
		Renderer renderer,
		GPUEffect effect,
		cstring path,
		CoordSys modelCoordSys,
		TextureMatcher texMatcher,
		float scale = 1.0f,
		int numInstances = 1
) {
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
			
			vec4 diffuseTint = vec4.one;
			vec4 specularTint = vec4.one;
			
			float smoothness = 0.1f;
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
				diffuseTint = sRGB_to_RGB(diffuseTint);
				

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

			efInst.setUniform("FragmentProgram.specularTex",
				specularTex
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
						) = 20.0f;
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


vec4 RGB_to_sRGB(vec4 rgb) {
	double tos(double l) {
		if (l < 0) {
			return 0;
		}
		
		if (l < 0.0031308f) {
			return l * 12.92f;
		} else {
			const float a = 0.055f;
			return (1 + a) * pow(l, 1.f / 2.4f) - a;
		}
	}
	
	return vec4[tos(rgb.r), tos(rgb.g), tos(rgb.b), rgb.a];
}


vec4 sRGB_to_RGB(vec4 srgb) {
	double froms(double nl) {
		if (nl < 0.0031308 * 12.92) {
			return nl / 12.92;
		} else {
			const double a = 0.055;
			return pow((nl + a) / (1 + a), 2.4);
		}
	}
	
	return vec4[froms(srgb.r), froms(srgb.g), froms(srgb.b), srgb.a];
}
