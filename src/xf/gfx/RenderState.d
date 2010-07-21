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
		bool	front = false;
		bool	back = true;
	}

	struct Viewport {
		int		x, y;
		uint	width, height;
	}

	struct Scissor {
		int		x, y;
		uint	width, height;
		bool	enabled = false;
	}

	struct Line {
		float	width = 1.0f;
	}

	struct Point {
		float	size = 1.0f;
	}
	
	
	Depth		depth;
	Blend		blend;
	CullFace	cullFace;
	Viewport	viewport;
	Scissor		scissor;
	Line		line;
	Point		point;
	bool		sRGB = true;
	bool		depthClamp = false;
}
