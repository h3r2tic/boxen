module xf.omg.color.RGB;

private {
	import xf.omg.core.Misc : pow;
	import xf.omg.core.LinearAlgebra : vec3, vec4;
}


template convertRGB(fromCS, toCS) {
	alias _convertRGB!(fromCS, toCS).convert convertRGB;
}


template _convertRGB(fromCS, toCS) {
	void convert(vec3 from, vec3* to) {
		// temporary, until more conversion are implemented
		static assert (is(fromCS.WhitePoint == WhitePoint.D65));
		static assert (fromCS.xR == toCS.xR);
		static assert (fromCS.xG == toCS.xG);
		static assert (fromCS.xB == toCS.xB);
		static assert (fromCS.yR == toCS.yR);
		static assert (fromCS.yG == toCS.yG);
		static assert (fromCS.yB == toCS.yB);
		
		to.r = toCS.Gamma.fromLinear(fromCS.Gamma.toLinear(from.r));
		to.g = toCS.Gamma.fromLinear(fromCS.Gamma.toLinear(from.r));
		to.b = toCS.Gamma.fromLinear(fromCS.Gamma.toLinear(from.r));
	}

	void convert(vec4 from, vec4* to) {
		convert(*cast(vec3*)&from, cast(vec3*)to);
		to.a = from.a;
	}
}



// Coordinates specified in the CIE 1931 space using the Standard Observer
interface WhitePoint {
	interface D65 {
		const real x = 0.31271;
		const real y = 0.32902;
	}

	interface E {
		const real x = 1.0 / 3.0;
		const real y = 1.0 / 3.0;
	}
}


interface Gamma {
	struct Linear {
		static real toLinear(real x) {
			return x;
		}

		static real fromLinear(real x) {
			return x;
		}
	}
	
	struct sRGB {
		static real toLinear(real x) {
			if (x < 0.0031308 * 12.92) {
				return x * (1.0 / 12.92);
			} else {
				const real a = 0.055;
				return pow((x + a) / (1.0 + a), 2.4);
			}
		}

		static real fromLinear(real x) {
			if (x < 0.0) {
				return 0.0;
			}
			
			if (x < 0.0031308) {
				return x * 12.92;
			} else {
				const real a = 0.055;
				return (1 + a) * pow(x, 1.0 / 2.4) - a;
			}
		}
	}
}


interface RGBSpace {
	struct sRGB {
		alias .WhitePoint.D65	WhitePoint;
		alias .Gamma.sRGB		Gamma;
		
		const real xR = 0.64;
		const real yR = 0.33;
		
		const real xG = 0.30;
		const real yG = 0.60;
		
		const real xB = 0.15;
		const real yB = 0.06;
	}


	struct Linear_sRGB {
		alias .WhitePoint.D65	WhitePoint;
		alias .Gamma.Linear		Gamma;
		
		const real xR = 0.64;
		const real yR = 0.33;
		
		const real xG = 0.30;
		const real yG = 0.60;
		
		const real xB = 0.15;
		const real yB = 0.06;
	}
}
