module xf.gfx.Framebuffer;


private {
	import
		xf.gfx.Resource,
		xf.gfx.Texture;
		
	import xf.omg.core.LinearAlgebra;
}


typedef ResourceHandle FramebufferHandle;



struct RenderBuffer {
	vec2i					size;
	TextureInternalFormat	internalFormat;
}


enum FramebufferLocation {
	Invalid,
	Screen,
	Offscreen,
	Any
}


struct FramebufferConfig {
	const int numColorAttachments = 16;
	
	
	struct Attachment {
		enum Type {
			Texture,
			RenderBuffer
		}
		
		bool				present;
		Type				type;
		// union {
			Texture			tex;
			RenderBuffer	rb;
		// }
		
		void opAssign(Texture tex) {
			present = true;
			type = Type.Texture;
			this.tex = tex;
		}
		
		void opAssign(RenderBuffer rb) {
			present = true;
			type = Type.RenderBuffer;
			this.rb = rb;
		}
	}
	
	Attachment[numColorAttachments]
						color;
	Attachment			depth;

	FramebufferLocation	location;
	vec2i				size;
}


struct FramebufferSettings {
	bool[FramebufferConfig.numColorAttachments]
						clearColorEnabled;
	vec4[FramebufferConfig.numColorAttachments]
						clearColorValue;
						
	bool				clearDepthEnabled = true;
	float				clearDepthValue = 1.0f;
}


struct Framebuffer {
	alias FramebufferHandle Handle;
	mixin MResource;

	vec2i size() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IFramebufferMngr)_resMngr).getFramebufferSize(_resHandle);
	}
	
	FramebufferConfig config() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IFramebufferMngr)_resMngr).getFramebufferConfig(_resHandle);
	}
	
	FramebufferSettings* settings() {
		assert (_resHandle !is Handle.init);
		assert (_resMngr !is null);
		return (cast(IFramebufferMngr)_resMngr).getFramebufferSettings(_resHandle);
	}
}


interface IFramebufferMngr {
	Framebuffer				createFramebuffer(FramebufferConfig);
	vec2i					getFramebufferSize(FramebufferHandle);
	FramebufferConfig		getFramebufferConfig(FramebufferHandle);
	FramebufferSettings*	getFramebufferSettings(FramebufferHandle);
	void					framebuffer(Framebuffer);
	Framebuffer				framebuffer();
	Framebuffer				mainFramebuffer();
}
