module xf.gfx.Framebuffer;


private {
	import
		xf.gfx.Resource,
		xf.gfx.Texture;
		
	import xf.omg.core.LinearAlgebra;
}


typedef ResourceHandle FramebufferHandle;



struct RenderBuffer {
	TextureInternalFormat	internalFormat;
	vec2i					size;
}


enum FramebufferLocation {
	Invalid,
	Screen,
	Offscreen,
	Any
}


struct FramebufferConfig {
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
	
	FramebufferLocation	location;
	Attachment[16]		color;
	Attachment			depth;
	vec2i				size;
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
}


interface IFramebufferMngr {
	Framebuffer				createFramebuffer(FramebufferConfig cfg);
	vec2i					getFramebufferSize(FramebufferHandle);
	FramebufferConfig		getFramebufferConfig(FramebufferHandle);
	void					framebuffer(Framebuffer);
	Framebuffer				framebuffer();
}
