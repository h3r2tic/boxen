module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.test.gfx.Common,
	
	xf.img.Image,
	xf.img.FreeImageLoader,

	xf.omg.core.Misc,
	xf.omg.color.RGB,
	
	tango.io.Stdout;
	


void main(cstring[] args) {
	if (args.length < 2) {
		Stdout.formatln("Usage: {} [image file path]", args[0]);
	} else {
		(new TestApp(args[1..$])).run;
	}
}


class TestApp : GfxApp {
	Effect					effect;
	Mesh*					mesh;
	SimpleKeyboardReader	keyboard;
	Image					img;


	this (cstring[] args) {
		version (Demo) {
			const cstring mediaDir = `media/`;
		} else {
			const cstring mediaDir = `../../../media/`;
		}

		scope imgLoader = new FreeImageLoader;

		/+if (0 == args.length) {
			//img = imgLoader.load(mediaDir ~ "img/gir-vector.png");
			//img = imgLoader.load(mediaDir ~ "img/text3.png");
			img = imgLoader.load(mediaDir ~ "img/Lena.jpg");
		} else {+/
			img = imgLoader.load(args[0]);
		//}
	}


	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.width = img.width;
		wnd.height = img.height;
	}
	

	override void initialize() {
		keyboard = new SimpleKeyboardReader(inputHub.mainChannel);

		mesh = renderer.createMeshes(1).ptr;

		effect = renderer.createEffect(
			"dualSrcBlend",
			EffectSource.filePath("dualSrcBlend.cgfx")
		);
		effect.compile();
		EffectHelper.allocateDefaultUniformStorage(effect);
		
		final efInst = renderer.instantiateEffect(effect);
		EffectHelper.allocateDefaultUniformStorage(efInst);
		EffectHelper.allocateDefaultVaryingStorage(efInst);

		TextureRequest req;
		req.minFilter = TextureMinFilter.Linear;
		req.magFilter = TextureMagFilter.Linear;
		/+req.wrapS = TextureWrap.ClampToEdge;
		req.wrapT = TextureWrap.ClampToEdge;+/
		final tex = renderer.createTexture(img, req);

		efInst.setUniform("FragmentProgram.tex", tex);
		efInst.setUniform("FragmentProgram.texSize", vec2.from(img.size));
		efInst.setUniform("FragmentProgram.winSize", vec2(window.width, window.height));

		vec2[] vertices = [
			vec2[-1, -1],
			vec2[1, -1],
			vec2[1, 1],
			vec2[-1, 1]
		];
		
		auto vb = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			cast(void[])vertices
		);
		delete vertices;

		uint[] indices = [
			0, 1, 2,
			0, 2, 3
		];

		with (*efInst.getVaryingParamData("VertexProgram.input.position")) {
			*buffer = vb;
			*attrib = VertexAttrib(
				0,
				vec2.sizeof,
				VertexAttrib.Type.Vec2
			);
		}

		mesh.indexData.numIndices = indices.length;
		
		uword minIdx = uword.max;
		uword maxIdx = uword.min;
		
		foreach (i; indices) {
			if (i < minIdx) minIdx = i;
			if (i > maxIdx) maxIdx = i;
		}

		mesh.indexData.minIndex = minIdx;
		mesh.indexData.maxIndex = maxIdx;
		
		(mesh.indexBuffer = renderer.createIndexBuffer(
			BufferUsage.StaticDraw,
			indices
		)).dispose();
		
		mesh.effectInstance = efInst;
	}


	float clearVal = 0.3f;
	vec2 offset = vec2.zero;
	vec2 winFraction = { x: 1.0f / 3.0f, y: 1.0f };
	int mode = 1;
	int alignment = 0;
	
	override void render() {
		final renderList = renderer.createRenderList();
		assert (renderList !is null);
		scope (success) renderer.disposeRenderList(renderList);

		final bin = renderList.getBin(mesh.effectInstance.getEffect);
		mesh.toRenderableData(bin.add(mesh.effectInstance));
		
		static bool prevSpDn = false;
		if (keyboard.keyDown(KeySym.space)) {
			if (!prevSpDn) {
				++alignment;
				alignment %= 4;
				Stdout.formatln("Subpixel alignment: {}.", [
					"Horizontal RGB (common - landscape mode)",
					"Vertical RGB (common - portrait mode)",
					"Horizontal BGR (rare - landscape mode)",
					"Vertical BGR (rare - portrait mode)"
				][alignment]);

				if (alignment % 2 == 0) {
					winFraction = vec2(1.0f / 3.0f, 1.0f);
				} else {
					winFraction = vec2(1.0f, 1.0f / 3.0f);
				}
			}
			prevSpDn = true;
		} else {
			prevSpDn = false;
		}

		{
			const vec2[] alArr = [
				{ x: -1.0f, y: 0.0f },
				{ x: 0.0f, y: 1.0f },
				{ x: 1.0f, y: 0.0f },
				{ x: 0.0f, y: -1.0f }
			];
			effect.setUniform("subpixelAlignment", alArr[alignment]);
		}

		effect.setUniform("winFraction", winFraction);

		int prevMode = mode;
		if (keyboard.keyDown(KeySym._1)) mode = 1;
		if (keyboard.keyDown(KeySym._2)) mode = 2;
		if (keyboard.keyDown(KeySym._3)) mode = 3;

		if (mode != prevMode) {
			Stdout.formatln("Filtering mode: {}.", [
				"Bilinear",
				"3 bilinear samples per pixel",
				"Subpixel"
			][mode-1]);
		}

		effect.setUniform("mode", mode);

		final state = renderer.state();
		state.blend.enabled = true;

		if (3 == mode) {
			state.blend.src = RenderState.Blend.Factor.Src1Color;
			state.blend.dst = RenderState.Blend.Factor.OneMinusSrc1Color;
		} else {
			state.blend.src = RenderState.Blend.Factor.Src0Alpha;
			state.blend.dst = RenderState.Blend.Factor.OneMinusSrc0Alpha;
		}

		const float scrollSpeed = 0.00001f;
		if (keyboard.keyDown(KeySym.Up)) offset.y -= scrollSpeed;
		if (keyboard.keyDown(KeySym.Down)) offset.y += scrollSpeed;
		if (keyboard.keyDown(KeySym.Left)) offset.x += scrollSpeed;
		if (keyboard.keyDown(KeySym.Right)) offset.x -= scrollSpeed;

		mesh.effectInstance.setUniform("FragmentProgram.offset", offset);

		if (keyboard.keyDown(KeySym.equal)) {
			clearVal += 0.001f;
		}

		if (keyboard.keyDown(KeySym.minus)) {
			clearVal -= 0.001f;
		}

		clearVal = max(0, min(1, clearVal));
		vec4 clearColor = vec4.one * clearVal;

		convertRGB
			!(RGBSpace.sRGB, RGBSpace.Linear_sRGB)
			(clearColor, &clearColor);

		renderList.sort();
		renderer.resetStats();
		renderer.framebuffer.settings.clearColorValue[0] = clearColor;
		renderer.clearBuffers();
		renderer.render(renderList);
	}
}
