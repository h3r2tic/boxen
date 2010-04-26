module xf.gfx.RenderState;



// TODO: more!
struct RenderState {
	struct Depth {
		bool	enabled		= true;
		bool	writeMask	= true;
	}
	
	struct Blend {
		enum Factor {
			Src0Color,
			Src1Color,
			Src0Alpha,
			Src1Alpha,
			DstColor,
			DstAlpha,
			OneMinusSrc0Color,
			OneMinusSrc1Color,
			OneMinusSrc0Alpha,
			OneMinusSrc1Alpha,
			OneMinusDstColor,
			OneMinusDstAlpha,
			Zero,
			One
		}
		
		Factor	src = Factor.Src0Alpha;
		Factor	dst = Factor.OneMinusSrc0Alpha;
		bool	enabled	= false;
	}

	struct CullFace {
		bool	enabled = false;
	}
	
	
	Depth		depth;
	Blend		blend;
	CullFace	cullFace;
}
