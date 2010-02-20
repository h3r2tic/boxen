module xf.gfx.RenderState;



// TODO: more!
struct RenderState {
	struct Depth {
		bool	enabled		= true;
		bool	writeMask	= true;
	}
	
	struct Blend {
		bool	enabled	= false;
	}
	
	struct CullFace {
		bool	enabled = false;
	}
	
	
	Depth		depth;
	Blend		blend;
	CullFace	cullFace;
}
