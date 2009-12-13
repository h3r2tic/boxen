module xf.omg.misc.Angle;



float circleAbsDiff(float fullCircle)(float a, float b) {
	while (a < 0.f) a += fullCircle;
	while (b < 0.f) b += fullCircle;
	while (a >= fullCircle) a -= fullCircle;
	while (b >= fullCircle) b -= fullCircle;
	float diff = a - b;
	if (diff < 0.f) diff = -diff;
	
	if (fullCircle - diff < diff) {
		return fullCircle - diff;
	}
	else return diff;
}



float circleDiff(float fullCircle)(float from, float to) {
	float diff = to - from;
	while (diff > fullCircle/2) diff -= fullCircle;
	while (diff < -fullCircle/2) diff += fullCircle;
	return diff;
}



struct YawPitch {
	float	yaw;
	float	pitch;
	
	
	const YawPitch zero = { yaw: 0.f, pitch: 0.f };
	
	void opAddAssign(YawPitch rhs) {
		yaw += rhs.yaw;
		pitch += rhs.pitch;
	}
	
	YawPitch opAdd(YawPitch rhs) {
		return YawPitch(yaw+rhs.yaw, pitch+rhs.pitch);
	}
}
