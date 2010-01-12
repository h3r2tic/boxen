module xf.gfx.gl3.CgEffect;

private {
	import xf.Common;	
	import xf.gfx.Log : log = gfxLog;
	import xf.gfx.GPUEffect;
	import xf.gfx.api.gl3.Cg;
}



class CgEffect : GPUEffect {
	this (cstring name, CGeffect handle) {
		this._name = name;
		this._handle = handle;
	
		auto techId = cgGetFirstTechnique(_handle);
		while (techId && cgValidateTechnique(techId) == CG_FALSE) {
			log.info("{}: Technique {} did not validate. Skipping",
				_name, fromStringz(cgGetTechniqueName(techId))
			);
			log.info(
				"Listing: {}",
				fromStringz(cgGetLastListing(cgGetEffectContext(_handle)))
			);
			
			techId = cgGetNextTechnique(techId);
		}
	}
	
	
	final override void setArraySize(cstring name, size_t size) {
		assert (false, "TODO");
	}
	
	
	final override void setUniformType(cstring name, cstring typeName) {
		assert (false, "TODO");
	}
	
	
	final override CgEffect copy() {
		assert (false, "TODO");
	}

	
	cstring		_name;
	CGeffect	_handle;
}
