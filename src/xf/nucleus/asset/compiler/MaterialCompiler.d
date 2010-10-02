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
	import xf.img.Image;
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
	Texture maskTex;
	Texture normalTex;
	Texture emissiveTex;

	vec4	albedoTint = vec4.one;
	vec4	specularTint = vec4.one;
	float	roughness = 0.9f;

	float	albedoTexAmount = 0.0f;
	float	specularTexAmount = 0.0f;
	float	emissiveTexAmount = 0.0f;

	vec2	albedoTexTile = vec2.one;
	vec2	specularTexTile = vec2.one;
	vec2	maskTexTile = vec2.one;
	vec2	normalTexTile = vec2.one;
	vec2	emissiveTexTile = vec2.one;
			
	/+
			float smoothness = 0.1f;
			float ior = 1.5f;
	//ior = material.ior;
	+/
	
	enum {
		AlbedoIdx = 1,
		SpecularIdx = 2,
		RoughnessIdx = 3,
		EmissiveIdx = 5,
		MaskIdx = 6,
		NormalIdx = 8
	}
	
	if (auto map = material.getMap(AlbedoIdx)) {
		TextureAssetCompilationOptions topts;
		topts.imgBaseDir = opts.imgBaseDir;
		albedoTex = compileTextureAsset(map, allocator, topts);
		albedoTexTile = map.uvTile;
		albedoTexAmount = map.amount;
	} else {
		TextureAssetCompilationOptions topts;
		albedoTex = compileTextureAsset("img/white.bmp", allocator, topts);
	}

	if (auto map = material.getMap(SpecularIdx)) {
		TextureAssetCompilationOptions topts;
		topts.imgBaseDir = opts.imgBaseDir;
		specularTex = compileTextureAsset(map, allocator, topts);
		specularTexTile = map.uvTile;
		specularTexAmount = map.amount;
	} else {
		TextureAssetCompilationOptions topts;
		specularTex = compileTextureAsset("img/white.bmp", allocator, topts);
	}

	if (auto map = material.getMap(MaskIdx)) {
		TextureAssetCompilationOptions topts;
		topts.imgBaseDir = opts.imgBaseDir;
		maskTex = compileTextureAsset(map, allocator, topts);
		maskTexTile = map.uvTile;
	} else {
		TextureAssetCompilationOptions topts;
		maskTex = compileTextureAsset("img/white.bmp", allocator, topts);
	}

	if (auto map = material.getMap(NormalIdx)) {
		TextureAssetCompilationOptions topts;
		topts.imgBaseDir = opts.imgBaseDir;
		normalTex = compileTextureAsset(map, allocator, topts);
		normalTex.colorSpace.value = Image.ColorSpace.Linear;
		normalTexTile = map.uvTile;
	} else {
		TextureAssetCompilationOptions topts;
		normalTex = compileTextureAsset("img/defnormal.bmp", allocator, topts);
		normalTex.colorSpace.value = Image.ColorSpace.Linear;
	}

	if (auto map = material.getMap(EmissiveIdx)) {
		TextureAssetCompilationOptions topts;
		topts.imgBaseDir = opts.imgBaseDir;
		emissiveTex = compileTextureAsset(map, allocator, topts);
		emissiveTexTile = map.uvTile;
		emissiveTexAmount = map.amount;
	} else {
		TextureAssetCompilationOptions topts;
		emissiveTex = compileTextureAsset("img/black.bmp", allocator, topts);
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

	uword numParams = 11;
	if (albedoTex) ++numParams;
	if (specularTex) ++numParams;
	if (maskTex) ++numParams;
	if (normalTex) ++numParams;
	if (emissiveTex) ++numParams;
	
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

		if (maskTex) {
			name[i] = "maskTex";
			valueType[i] = ParamValueType.ObjectRef;
			value[i] = cast(void*)maskTex;
			++i;
		}

		if (normalTex) {
			name[i] = "normalTex";
			valueType[i] = ParamValueType.ObjectRef;
			value[i] = cast(void*)normalTex;
			++i;
		}

		if (emissiveTex) {
			name[i] = "emissiveTex";
			valueType[i] = ParamValueType.ObjectRef;
			value[i] = cast(void*)emissiveTex;
			++i;
		}

		name[i] = "albedoTexTile";
		valueType[i] = ParamValueType.Float2;
		value[i] = cast(void*)allocator._new!(vec2)(albedoTexTile.tuple);
		++i;

		name[i] = "specularTexTile";
		valueType[i] = ParamValueType.Float2;
		value[i] = cast(void*)allocator._new!(vec2)(specularTexTile.tuple);
		++i;

		name[i] = "maskTexTile";
		valueType[i] = ParamValueType.Float2;
		value[i] = cast(void*)allocator._new!(vec2)(maskTexTile.tuple);
		++i;

		name[i] = "normalTexTile";
		valueType[i] = ParamValueType.Float2;
		value[i] = cast(void*)allocator._new!(vec2)(maskTexTile.tuple);
		++i;

		name[i] = "emissiveTexTile";
		valueType[i] = ParamValueType.Float2;
		value[i] = cast(void*)allocator._new!(vec2)(emissiveTexTile.tuple);
		++i;

		name[i] = "albedoTexAmount";
		valueType[i] = ParamValueType.Float;
		value[i] = cast(void*)allocator._new!(float)(albedoTexAmount);
		++i;

		name[i] = "specularTexAmount";
		valueType[i] = ParamValueType.Float;
		value[i] = cast(void*)allocator._new!(float)(specularTexAmount);
		++i;

		name[i] = "emissiveTexAmount";
		valueType[i] = ParamValueType.Float;
		value[i] = cast(void*)allocator._new!(float)(emissiveTexAmount);
		++i;

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

	assert (i == numParams);

	cmat.name = allocator.dupString(material.name);

	// TODO
	cmat.kernelName = "MaxDefaultMaterial";
	
	return cmat;
}
