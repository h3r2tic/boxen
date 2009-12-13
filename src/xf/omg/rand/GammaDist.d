module xf.omg.rand.GammaDist;

import
	tango.math.Math,
	tango.math.random.Kiss,
	tango.math.GammaFunction,

	xf.omg.rand.Random,
	xf.omg.rand.MersenneTwister;


private real gamma1(real alpha){
	if (alpha < 1){
		real c = cast(real)1/alpha;
		real t = 0.07 + 0.75 * sqrt(1-alpha);
		real p = t / (t + alpha * exp(-t));
		real b = cast(real)1/p;
		while(true){
			real u = MersenneTwister.shared.getReal!("()")();
			real w = MersenneTwister.shared.getReal!("()")();
			real v = b*u;
			if(v <= 1){
				real x = t * pow(v,c);
				if( w <= ((2-x)/(2+x)) ) return x;
				if( w <= exp(-x) ) return x;
			} else {
				real x = -log(c*t*(b-v));
				real y = x/t;
				if( ( w*(alpha+y-alpha*y)) <= 1 ) return x;
				if( w <= pow(x/t, alpha - 1)) return x;
			}
		}
	} else {
		real d = cast(real)1 / sqrt(2*alpha -1);
		real c = alpha + cast(real)1/d;
		real b = alpha - log(4);
		while(true){
			real u1 = MersenneTwister.shared.getReal!("()")();
			real u2 = MersenneTwister.shared.getReal!("()")();
			real v = d * log(u1 / (1-u1));
			real x = alpha * exp(v);
			real z = u1*u1*u2;
			real r = b + c*v - x;
			if((r + (1+ log(d)) - d*z) >= 0) return x;
			if( r >= log(z)) return x;
		}
		
	}
}

real mygamma(real alpha, real fi=1){
	return gamma1(alpha)*fi;
}
/*	digited: added frand and phi here for gamma_density, still don't get what alpha is(was). Commented out for now
private
{
	Kiss rand;

	float frand()
	{
		return (1.0 / uint.max) * rand.natural;
	}
	
	const float phi;
}

static this()
{
	phi = frand() * 2 * pi;
}

float gamma_density(float x){
	float ret= exp(-x/phi);
	ret /= gamma(alpha)* pow(phi,alpha);
	ret *= pow(x,alpha-1);
	//Stdout(x,"->",ret,"");
	return ret;
}
*/