module xf.omg.rand.MersenneTwister;
import xf.omg.rand.Random;

final class MersenneTwister : Random!(MersenneTwister) {
	uint _getUint(){
		uint y;
		static uint mag01[2] =[0, MATRIX_A];

		if (mti >= mt.length) { 
			int kk;

			if (mti > mt.length) {
				seed( 5489UL ); 
			}

			for (kk=0; kk<mt.length-M; kk++)			{
				y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
				mt[kk] = mt[kk+M] ^ (y >> 1) ^ mag01[y & 1UL];
			}
			
			for (;kk<mt.length-1;kk++) {
				y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
				mt[kk] = mt[kk+(M-mt.length)] ^ (y >> 1) ^ mag01[y & 1UL];
			}
			y = (mt[mt.length-1]&UPPER_MASK)|(mt[0]&LOWER_MASK);
			
			mt[mt.length-1] = mt[M-1] ^ (y >> 1) ^ mag01[y & 1UL];

			mti = 0;
		}

		y = mt[mti++];

		y ^= (y >> 11);
		y ^= (y << 7)  &  0x9d2c5680UL;
		y ^= (y << 15) &  0xefc60000UL;
		y ^= (y >> 18);

		vLastRand = y;
		return y;
	}
	
	RandomGenerator seed(uint s){
		mt[0]= s &  0xffffffffUL;
		for (mti=1; mti<mt.length; mti++){
			mt[mti] = (1812433253UL * (mt[mti-1] ^ (mt[mti-1] >> 30)) + mti);
			mt[mti] &= 0xffffffffUL;
		}
		
		return this;
	}

	private{
		/* Period parameters */
		const uint N          = 624;
		const uint M          = 397;
		const uint MATRIX_A   = 0x9908b0df;   /* constant vector a */
		const uint UPPER_MASK = 0x80000000; /* most significant w-r bits */
		const uint LOWER_MASK = 0x7fffffff; /* least significant r bits */

		uint[N] mt; /* the array for the state vector  */
		uint mti=mt.length+1; /* mti==mt.length+1 means mt[] is not initialized */
		uint vLastRand; /* The most recent random uint returned. */
	}
}
