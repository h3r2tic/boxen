module xf.nucleus.util.SamplerLoading;

private {
	import
		xf.Common,
		xf.nucleus.SamplerDef,
		xf.nucleus.asset.CompiledTextureAsset,
		xf.gfx.Texture,
		xf.gfx.IRenderer : RendererBackend = IRenderer;

	import xf.nucleus.Log : error = nucleusError, log = nucleusLog;

	import
		xf.loader.Common,
		xf.loader.img.ImgLoader,
		xf.img.Image;
}



void loadMaterialSamplerParam(
	RendererBackend backend,
	SamplerDef sampler,
	Texture* tex
) {
	if (auto val = sampler.params.get("texture")) {
		cstring filePath;
		val.getValue(&filePath);

		auto img = imgLoader.load(getResourcePath(filePath));
		if (!img.valid) {
			log.warn("Could not load texture: '{}'", filePath);
			img = imgLoader.load(getResourcePath("img/testgrid.png"));
			if (!img.valid) {
				error("Could not fallback texture.");
			}
		}

		// TODO
		TextureRequest req;
		foreach (p; sampler.params) {
			if ("minFilter" == p.name) {
				cstring val;
				p.getValueIdent(&val);
				switch (val) {
					case "linear": req.minFilter = TextureMinFilter.Linear; break;
					case "nearest": req.minFilter = TextureMinFilter.Nearest; break;
					case "mipmapLinear": req.minFilter = TextureMinFilter.LinearMipmapLinear; break;
					default: log.error("Unrecognized texture min filter: '{}'", val);
				}
			}

			if ("magFilter" == p.name) {
				cstring val;
				p.getValueIdent(&val);
				switch (val) {
					case "linear": req.magFilter = TextureMagFilter.Linear; break;
					case "nearest": req.magFilter = TextureMagFilter.Nearest; break;
					default: log.error("Unrecognized texture mag filter: '{}'", val);
				}
			}
		}

		*tex = backend.createTexture(
			img,
			TextureCacheKey.path(filePath),
			req
		);
	} else {
		assert (false, "TODO: use a fallback texture");
	}
}


void loadMaterialSamplerParam(
	RendererBackend backend,
	CompiledTextureAsset sampler,
	Texture* tex
) {
	cstring filePath = sampler.bitmapPath;

	TextureRequest req;

	auto img = imgLoader.load(getResourcePath(filePath));
	if (sampler.colorSpace.available) {
		switch (*sampler.colorSpace.value) {
			case Image.ColorSpace.Linear: {
				req.internalFormat = TextureInternalFormat.RGBA8;
			} break;
			case Image.ColorSpace.sRGB: {
				req.internalFormat = TextureInternalFormat.SRGB8_ALPHA8;
			} break;
			
			default: assert (false);
		}
	}
	
	if (!img.valid) {
		log.warn("Could not load texture: '{}'", filePath);
		img = imgLoader.load(getResourcePath("img/testgrid.png"));
		if (!img.valid) {
			error("Could not fallback texture.");
		}
	}

	*tex = backend.createTexture(
		img,
		TextureCacheKey.path(filePath),
		req
	);
}
