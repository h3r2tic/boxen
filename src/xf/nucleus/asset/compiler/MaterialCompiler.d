module xf.nucleus.asset.compiler.MaterialCompiler;

private {
	import xf.Common;
	import xf.nucleus.Param;
	import xf.nucleus.asset.compiler.TextureCompiler;
	import xf.nucleus.asset.CompiledMaterialAsset;
	import xf.nucleus.asset.CompiledTextureAsset;
	import xf.loader.scene.model.Material : LoaderMaterial = Material;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.color.RGB;
	import xf.mem.ScratchAllocator;
}



// TODO: put this in the asset conditioning pipeline
CompiledMaterialAsset compileMaterialAsset(
	LoaderMaterial material,
	DgScratchAllocator allocator,
	MaterialAssetCompilationOptions opts = MaterialAssetCompilationOptions.init
) {
	final cmat = allocator._new!(CompiledMaterialAsset)();

	alias CompiledTextureAsset Texture;

	Texture albedoTex;
	Texture specularTex;

	vec4	albedoTint = vec4.one;
	vec4	specularTint = vec4.one;
	float	roughness = 0.9f;

	/+
			vec2 diffuseTexTile = vec2.one;
			vec2 specularTexTile = vec2.one;
			
			
			float smoothness = 0.1f;
			float ior = 1.5f;
	//ior = material.ior;
	+/
	
	enum {
		AlbedoIdx = 1,
		SpecularIdx = 2
	}
	
	if (auto map = material.getMap(AlbedoIdx)) {
		TextureAssetCompilationOptions topts;
		topts.imgBaseDir = opts.imgBaseDir;
		albedoTex = compileTextureAsset(map, allocator, topts);
		//diffuseTexTile = map.uvTile;
	} else {
		TextureAssetCompilationOptions topts;
		albedoTex = compileTextureAsset("img/white.bmp", allocator, topts);
	}

	if (auto map = material.getMap(SpecularIdx)) {
		TextureAssetCompilationOptions topts;
		topts.imgBaseDir = opts.imgBaseDir;
		specularTex = compileTextureAsset(map, allocator, topts);
		//specularTexTile = map.uvTile;
	} else {
		TextureAssetCompilationOptions topts;
		specularTex = compileTextureAsset("img/white.bmp", allocator, topts);
	}

	roughness = 1.0f - material.shininess;
	if (roughness < 0.01f) {
		roughness = 0.01f;
	}
	
	convertRGB
		!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)
		(material.diffuseTint, &albedoTint);

	convertRGB
		!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)
		(material.specularTint, &specularTint);

	uword numParams = 3;
	if (albedoTex) ++numParams;
	if (specularTex) ++numParams;
	
	cmat.params.length = numParams;

	cmat.params.name		= allocator.allocArray!(cstring)(numParams).ptr;
	cmat.params.valueType	= allocator.allocArray!(ParamValueType)(numParams).ptr;
	cmat.params.value		= allocator.allocArray!(void*)(numParams).ptr;

	uword i = 0;
	with (cmat.params) {
		if (albedoTex) {
			name[i] = "albedoTex";
			valueType[i] = ParamValueType.ObjectRef;
			value[i] = cast(void*)albedoTex;
			++i;
		}
		
		if (specularTex) {
			name[i] = "specularTex";
			valueType[i] = ParamValueType.ObjectRef;
			value[i] = cast(void*)specularTex;
			++i;
		}

		name[i] = "albedoTint";
		valueType[i] = ParamValueType.Float4;
		value[i] = cast(void*)allocator._new!(vec4)(albedoTint.tuple);
		++i;

		name[i] = "specularTint";
		valueType[i] = ParamValueType.Float4;
		value[i] = cast(void*)allocator._new!(vec4)(specularTint.tuple);
		++i;

		name[i] = "roughness";
		valueType[i] = ParamValueType.Float;
		value[i] = cast(void*)allocator._new!(float)(roughness);
		++i;
	}

	cmat.name = allocator.dupString(material.name);

	// TODO
	cmat.kernelName = "TestMaterial2";
	
	return cmat;
}
