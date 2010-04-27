// TODO: refactor. added just so Hybrid compiles
module xf.omg.color.HSV;

private {
	import tango.math.Math;
}


void hsv2rgb(float h, float s, float v, float* r, float* g, float* b) {
	if ( s == 0 ) {
		*r = v;
		*g = v;
		*b = v;
	} else {
		float var_h = h * 6;
		float var_i = floor( var_h );
		float var_1 = v * ( 1 - s );
		float var_2 = v * ( 1 - s * ( var_h - var_i ) );
		float var_3 = v * ( 1 - s * ( 1 - ( var_h - var_i ) ) );

		if      ( var_i == 0 ) { *r = v     ; *g = var_3 ; *b = var_1; }
		else if ( var_i == 1 ) { *r = var_2 ; *g = v     ; *b = var_1; }
		else if ( var_i == 2 ) { *r = var_1 ; *g = v     ; *b = var_3; }
		else if ( var_i == 3 ) { *r = var_1 ; *g = var_2 ; *b = v;     }
		else if ( var_i == 4 ) { *r = var_3 ; *g = var_1 ; *b = v;     }
		else                   { *r = v     ; *g = var_1 ; *b = var_2; }

	}
}


/+void rgb2hsv(float r, float g, float b, float *hr, float *sr, float *vr)
{
  double h, s, v, max, min, del, rc, gc, bc;

  max = max3(r, g, b);
  min = min3(r, g, b);

  del = max - min;
  v = max;
  s = max == 0.0 ? 0.0 : del / max;

  h = -1;					/* No hue */
  if (s != 0.0) {
    rc = (max - r) / del;
    gc = (max - g) / del;
    bc = (max - b) / del;

    if (r == max) h = bc - gc;
    else if (g == max) h = 2 + rc - bc;
    else /* if (b == max) */ h = 4 + gc - rc;

    h = h * 60;
    if (h < 0) h += 360;
  }

  *hr = h;  *sr = s;  *vr = v;
}
+/
