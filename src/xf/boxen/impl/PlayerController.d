module xf.boxen.impl.PlayerController;

private {
	import xf.boxen.model.IPlayerController;
	
	import xf.net.NetObj;
	import xf.game.GameObj;
	import xf.game.Defs;
	import xf.utils.BitStream;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.misc.Angle;

	import xf.boxen.Rendering;
	import DebugDraw = xf.boxen.DebugDraw;
}



struct PosRotState {
	vec3fi	pos = vec3fi.zero;
	float	yaw = 0.0f;
	float	pitch = 0.0f;

	void serialize(BitStreamWriter* bs) {
		bs.write(pos.x.store);
		bs.write(pos.y.store);
		bs.write(pos.z.store);
		bs.write(yaw);
		bs.write(pitch);
	}
	
	void unserialize(BitStreamReader* bs) {
		bs.read(&pos.x.store);
		bs.read(&pos.y.store);
		bs.read(&pos.z.store);
		bs.read(&yaw);
		bs.read(&pitch);
	}

	void applyDiff(PosRotState* a, PosRotState* b, float t) {
		pos += (b.pos - a.pos) * t;
		yaw += (b.yaw - a.yaw) * t;
		pitch += (b.pitch - a.pitch) * t;
	}

	static float calcDifference(PosRotState* a, PosRotState* b) {
		// TODO
		return
			vec3.from(a.pos - b.pos).length
			+ (circleAbsDiff!(360.f)(a.yaw, b.yaw) / 180.f) * .2f
			+ (circleAbsDiff!(360.f)(a.pitch, b.pitch) / 180.f) * .2f;
	}
}


final class PlayerController : NetObj, IPlayerController {
	this(vec3 off, objId id, playerId owner) {
		_coordSys = CoordSys(vec3fi.from(off), quat.identity);
		_owner = owner;
		_id = id;
		initializeNetObj();

		addMesh(
			DebugDraw.create(DebugDraw.Prim.Box),
			CoordSys.identity,
			id
		);
	}

	// Implement NetObj
	playerId	authOwner() {
		return _auth;
	}
	
	void		setAuthOwner(playerId pid) {
		_auth = pid;
	}	
	
	playerId	realOwner() {
		return _owner;
	}
	
	void		setRealOwner(playerId pid) {
		_owner = pid;
	}

	void		dispose() {
	}
	// ----

	// Implements GameObj, IPlayerController
	vec3fi		worldPosition() {
		return _coordSys.origin;
	}
	
	// Implement IPlayerController
	void	move(vec3 v) {
		_movePending += v;
	}
	
	void	yawRotate(float a) {
		_rotationPending.yaw += a;
	}
	
	void	pitchRotate(float a) {
		_rotationPending.pitch += a;
	}
	
	vec3	worldDirection() {
		return _coordSys.rotation.xform(-vec3.unitZ);
	}
	
	void	teleport(vec3fi p) {
		_coordSys.origin = p;
	}
	
	quat	rotationQuat() {
		return _coordSys.rotation;
	}
	// ----


	// Implements GameObj
	void update(double) {
		_rotation += _rotationPending;
		if (_rotation.pitch > 90.f) {
			_rotation.pitch = 90.f;
		}
		if (_rotation.pitch < -90.f) {
			_rotation.pitch = -90.f;
		}
		_rotationPending = YawPitch.zero;

		final moveQuat = quat.yRotation(_rotation.yaw);
		final move = moveQuat.xform(_movePending);

		_coordSys.rotation = moveQuat * quat.xRotation(_rotation.pitch);
		_coordSys.origin += vec3fi.from(move);

		_movePending = vec3.zero;
		_rotationPending = YawPitch.zero;
	}

	

	CoordSys	_coordSys = CoordSys.identity;
	YawPitch	_rotation = YawPitch.zero;

	vec3		_movePending = vec3.zero;
	YawPitch	_rotationPending = YawPitch.zero;
	
	playerId	_owner;
	playerId	_auth;

	void storeState(PosRotState* st) {
		st.pos = _coordSys.origin;
		st.yaw = _rotation.yaw;
		st.pitch = _rotation.pitch;
	}
	
	void loadState(PosRotState* st) {
		_coordSys.origin = st.pos;
		_rotation.yaw = st.yaw;
		_rotation.pitch = st.pitch;
	}

	mixin DeclareNetState!(PosRotState);
	mixin MNetObj;
	mixin MGameObj;
}
