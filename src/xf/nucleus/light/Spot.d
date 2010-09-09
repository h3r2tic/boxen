module xf.nucleus.light.Spot;

private {
	import xf.Common;
	import xf.nucleus.Light;
	import xf.nucleus.KernelParamInterface;
	import xf.nucleus.Nucleus;
	import xf.nucleus.Defs;
	import xf.nucleus.Renderable;
	import xf.nucleus.post.PostProcessor;

	import xf.gfx.Framebuffer;
	
	import xf.loader.Common;
	import xf.loader.img.ImgLoader;	
	
	import xf.gfx.Texture;
	import xf.gfx.TextureCache;

	import xf.vsd.VSD;

	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.util.ViewSettings;

	import xf.nucleus.Log;
}



private {
	PostProcessor vsmPost;
	
	template MSpotCommon() {
		Texture	spotlightMask;

		void loadSpotlightMask() {
			if (!spotlightMask.valid) {
				cstring filePath = `img/spotlight.dds`;
				final img = imgLoader.load(getResourcePath(filePath));
				if (!img.valid) {
					nucleusError("Could not load texture: '{}'", filePath);
				}

				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.SRGB8_ALPHA8;

				// Texture derivatives are borked in deferred rendering,
				// so let's just be cheap bastards and don't use mips :P
				treq.minFilter = TextureMinFilter.Linear;
				treq.magFilter = TextureMagFilter.Linear;
				treq.wrapS = TextureWrap.ClampToEdge;
				treq.wrapT = TextureWrap.ClampToEdge;
				
				spotlightMask = rendererBackend.createTexture(
					img,
					TextureCacheKey.path(filePath),
					treq
				);
			}
		}
	}
}


class SpotLight_VSM : Light {
	mixin MSpotCommon;
	
	override cstring kernelName() {
		return "SpotLight_VSM";
	}

	override void prepareRenderData(VSDRoot* vsd) {
		calcInfluenceRadius();

		if (vsmPost is null) {
			vsmPost = new PostProcessor(rendererBackend, kdefRegistry);
			vsmPost.setKernel("VSMBlur");
		}

		loadSpotlightMask();

		if (!depthFb.valid) {
			final cfg = FramebufferConfig();
			cfg.size = shadowMapSize;
			cfg.location = FramebufferLocation.Offscreen;

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.RG32F;
				treq.minFilter = TextureMinFilter.Linear;
				treq.magFilter = TextureMagFilter.Linear;
				treq.wrapS = TextureWrap.ClampToBorder;
				treq.wrapT = TextureWrap.ClampToBorder;
				cfg.color[0] = depthTex = rendererBackend.createTexture(
					shadowMapSize,
					treq
				);
				assert (depthTex.valid);
			}
				
			depthFb = rendererBackend.createFramebuffer(cfg);
			assert (depthFb.valid);
		}

		if (!sharedDepthFb.valid) {
			final cfg = FramebufferConfig();
			cfg.size = shadowMapSize;
			cfg.location = FramebufferLocation.Offscreen;

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.RG32F;
				treq.minFilter = TextureMinFilter.Linear;
				treq.magFilter = TextureMagFilter.Linear;
				treq.wrapS = TextureWrap.ClampToBorder;
				treq.wrapT = TextureWrap.ClampToBorder;
				cfg.color[0] = sharedDepthTex = rendererBackend.createTexture(
					shadowMapSize,
					treq
				);
				assert (sharedDepthTex.valid);
			}
				
			cfg.depth = RenderBuffer(
				shadowMapSize,
				TextureInternalFormat.DEPTH_COMPONENT32F
			);

			sharedDepthFb = rendererBackend.createFramebuffer(cfg);
			assert (sharedDepthFb.valid);
		}
		
		vec3 target = vec3.zero;		// HACK
		this.worldToView = mat4.lookAt(this.position, target);
		assert (this.worldToView.ok);
		
		this.viewToClip = mat4.perspective(
			60.0f,		// fov
			1.0,		// aspect
			0.1f,		// near plane
			influenceRadius		// far plane
		);
		assert (this.viewToClip.ok);
		
		this.worldToClip = viewToClip * worldToView;
		assert (this.worldToClip.ok);

		final nr = vsmRenderer;
		final rlist = nr.createRenderList();
		final origFb = rendererBackend.framebuffer;
		final origState = *rendererBackend.state();
		
		scope (exit) {
			rendererBackend.framebuffer = origFb;
			*rendererBackend.state() = origState;
			nr.disposeRenderList(rlist);
		}

		rendererBackend.resetState();

		rendererBackend.framebuffer = sharedDepthFb;
		rendererBackend.framebuffer.settings.clearColorValue[0] = vec4.zero;
		rendererBackend.clearBuffers();

		auto viewCs = CoordSys(worldToView).inverse;
		final viewSettings = ViewSettings(
			viewCs,
			60.0f,		// fov
			1.0,		// aspect
			0.1f,		// near plane
			influenceRadius		// far plane
		);

		vsd.findVisible(viewSettings, (VisibleObject[] olist) {
			foreach (o; olist) {
				final bin = rlist.add();
				static assert (RenderableId.sizeof == typeof(o.id).sizeof);
				rlist.list.renderableId[bin] = cast(RenderableId)o.id;
				rlist.list.coordSys[bin] = renderables.transform[o.id];
			}
		});

		with (rendererBackend.state.cullFace) {
			enabled = true;
			front = false;
			back = true;
		}

		nr.render(viewSettings, vsd, rlist);

		rendererBackend.framebuffer = depthFb;
		vsmPost.render(sharedDepthTex);
	}

	vec2i shadowMapSize = { x: 512, y: 512 };
	
	mat4 worldToView;
	mat4 viewToClip;
	mat4 worldToClip;

	Framebuffer depthFb;
	Texture		depthTex;
	
	static Framebuffer	sharedDepthFb;
	static Texture		sharedDepthTex;

	override void setKernelData(KernelParamInterface kpi) {
		kpi.bindUniform("lightPos", &position);
		kpi.bindUniform("lumIntens", &lumIntens);
		kpi.bindUniform("influenceRadius", &influenceRadius);
		kpi.bindUniform("depthSampler", &depthTex);
		kpi.bindUniform("spotlightMask", &spotlightMask);
		kpi.bindUniform("light_worldToClip", &worldToClip);
	}
}


class SpotLight_SM : Light {
	mixin MSpotCommon;
	
	override cstring kernelName() {
		return "SpotLight_SM";
	}

	override void prepareRenderData(VSDRoot* vsd) {
		calcInfluenceRadius();

		loadSpotlightMask();

		if (!depthFb.valid) {
			final cfg = FramebufferConfig();
			cfg.size = shadowMapSize;
			cfg.location = FramebufferLocation.Offscreen;

			{
				TextureRequest treq;
				treq.internalFormat = TextureInternalFormat.DEPTH_COMPONENT32F;
				treq.minFilter = TextureMinFilter.Nearest;
				treq.magFilter = TextureMagFilter.Nearest;
				treq.wrapS = TextureWrap.ClampToBorder;
				treq.wrapT = TextureWrap.ClampToBorder;
				cfg.depth = depthTex = rendererBackend.createTexture(
					shadowMapSize,
					treq
				);
				assert (depthTex.valid);
			}
				
			depthFb = rendererBackend.createFramebuffer(cfg);
			assert (depthFb.valid);
		}

		vec3 target = vec3.zero;		// HACK
		this.worldToView = mat4.lookAt(this.position, target);
		assert (this.worldToView.ok);
		
		this.viewToClip = mat4.perspective(
			60.0f,		// fov
			1.0,		// aspect
			0.1f,		// near plane
			influenceRadius		// far plane
		);
		assert (this.viewToClip.ok);
		
		this.worldToClip = viewToClip * worldToView;
		assert (this.worldToClip.ok);

		final nr = smRenderer;
		final rlist = nr.createRenderList();
		final origFb = rendererBackend.framebuffer;
		final origState = *rendererBackend.state();
		
		scope (exit) {
			rendererBackend.framebuffer = origFb;
			*rendererBackend.state() = origState;
			nr.disposeRenderList(rlist);
		}

		rendererBackend.resetState();

		rendererBackend.framebuffer = depthFb;
		rendererBackend.framebuffer.settings.clearDepthValue = 1;
		rendererBackend.clearBuffers();

		auto viewCs = CoordSys(worldToView).inverse;
		final viewSettings = ViewSettings(
			viewCs,
			60.0f,		// fov
			1.0,		// aspect
			0.1f,		// near plane
			influenceRadius		// far plane
		);

		vsd.findVisible(viewSettings, (VisibleObject[] olist) {
			foreach (o; olist) {
				final bin = rlist.add();
				static assert (RenderableId.sizeof == typeof(o.id).sizeof);
				rlist.list.renderableId[bin] = cast(RenderableId)o.id;
				rlist.list.coordSys[bin] = renderables.transform[o.id];
			}
		});

		with (rendererBackend.state.cullFace) {
			enabled = true;
			front = false;
			back = true;
		}

		nr.render(viewSettings, vsd, rlist);
	}

	vec2i shadowMapSize = { x: 512, y: 512 };
	
	mat4 worldToView;
	mat4 viewToClip;
	mat4 worldToClip;

	Framebuffer depthFb;
	Texture		depthTex;

	override void setKernelData(KernelParamInterface kpi) {
		kpi.bindUniform("lightPos", &position);
		kpi.bindUniform("lumIntens", &lumIntens);
		kpi.bindUniform("influenceRadius", &influenceRadius);
		kpi.bindUniform("depthSampler", &depthTex);
		kpi.bindUniform("spotlightMask", &spotlightMask);
		kpi.bindUniform("light_worldToClip", &worldToClip);
	}
}
