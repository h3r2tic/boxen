module xf.boxen.impl.PlayerController;

private {
	import xf.Common;
	
	import xf.boxen.model.IPlayerController;
	import InteractionTracking = xf.game.InteractionTracking;
	
	import xf.net.NetObj;
	import xf.game.GameObj;
	import xf.game.Defs;
	import xf.utils.BitStream;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.misc.Angle;

	import xf.boxen.Rendering;
	import DebugDraw = xf.boxen.DebugDraw;
	import Phys = xf.boxen.Phys;
	import xf.havok.Havok;
	import tango.stdc.stdio;
}



struct PosRotState {
	vec3fi	pos = vec3fi.zero;
	vec3	vel = vec3.zero;
	float	yaw = 0.0f;
	float	pitch = 0.0f;

	void serialize(BitStreamWriter* bs) {
		bs.write(pos.x.store);
		bs.write(pos.y.store);
		bs.write(pos.z.store);
		bs.write(vel.x);
		bs.write(vel.y);
		bs.write(vel.z);
		bs.write(yaw);
		bs.write(pitch);
	}
	
	void unserialize(BitStreamReader* bs) {
		bs.read(&pos.x.store);
		bs.read(&pos.y.store);
		bs.read(&pos.z.store);
		bs.read(&vel.x);
		bs.read(&vel.y);
		bs.read(&vel.z);
		bs.read(&yaw);
		bs.read(&pitch);
	}

	void applyDiff(PosRotState* a, PosRotState* b, float t) {
		pos += (b.pos - a.pos) * t;
		vel += (b.vel - a.vel) * t;
		yaw += (b.yaw - a.yaw) * t;
		pitch += (b.pitch - a.pitch) * t;
	}

	static float calcDifference(PosRotState* a, PosRotState* b) {
		// TODO
		return
			vec3.from(a.pos - b.pos).length
			+ (a.vel - b.vel).length * 0.3f
			+ (circleAbsDiff!(360.f)(a.yaw, b.yaw) / 180.f) * 2.0f
			+ (circleAbsDiff!(360.f)(a.pitch, b.pitch) / 180.f) * 2.0f;
	}

	char[] toString() {
		static char[256] buf;
		sprintf(
			buf.ptr, "pos:%f %f %f vel: %f %f %f yaw: %f pitch: %f",
			vec3.from(pos).tuple,
			vel.tuple,
			yaw,
			pitch
		);
		return fromStringz(buf.ptr);
	}
}


final class PlayerController : NetObj, IPlayerController {
	this(vec3 off, objId id, playerId owner) {
		_coordSys = CoordSys(vec3fi.from(off), quat.identity);
		_id = id;
		
		initPhys(off);
		initializeNetObj(owner);

		addMesh(
			DebugDraw.create(DebugDraw.Prim.Cylinder),
			CoordSys(vec3fi[0, 0.9, 0], quat.identity),
			id,
			vec3(1.2, 1.8, 1.2)
		);
	}

	hkpShape 					_shape;
	hkpSimpleShapePhantom		_phantom;
	hkpCharacterProxy			_proxy;
	hkpCharacterContext			_characterContext;

	static {
		hkpCharacterStateManager	_stateMngr;
	}
	

	private void initPhys(vec3 off) {
		Phys.world.markForWrite();
		scope (success) Phys.world.unmarkForWrite();

		if (_stateMngr._impl is null) {
			_stateMngr = hkpCharacterStateManager();

			{
				final state = hkpCharacterStateOnGround()._as_hkpCharacterState();
				_stateMngr.registerState(state,	hkpCharacterStateType.HK_CHARACTER_ON_GROUND);
				state.removeReference();
			}
			{
				final state = hkpCharacterStateInAir()._as_hkpCharacterState();
				_stateMngr.registerState(state,	hkpCharacterStateType.HK_CHARACTER_IN_AIR);
				state.removeReference();
			}
			{
				final state = hkpCharacterStateJumping()._as_hkpCharacterState();
				_stateMngr.registerState(state,	hkpCharacterStateType.HK_CHARACTER_JUMPING);
				state.removeReference();
			}
			{
				final state = hkpCharacterStateClimbing()._as_hkpCharacterState();
				_stateMngr.registerState(state,	hkpCharacterStateType.HK_CHARACTER_CLIMBING);
				state.removeReference();
			}
		}
		
		_shape = hkpCapsuleShape(
			hkVector4(vec3(0, 0.6, 0)),
			hkVector4(vec3(0, 1.2, 0)),
			0.6f
		)._as_hkpShape();

		_phantom = hkpSimpleShapePhantom(
			_shape,
			hkTransform.identity,
			0
		);

		_phantom.setUserData(cast(uword)cast(void*)this);

		Phys.world.addPhantom(_phantom._as_hkpPhantom).removeReference();

		auto cpci = hkpCharacterProxyCinfo();
		cpci.m_position = hkVector4(off);
		cpci.m_staticFriction = 0.0f;
		cpci.m_dynamicFriction = 1.0f;
		cpci.m_up = hkVector4.unitY;
		cpci.m_userPlanes = 4;
		cpci.m_maxSlope = 3.1415926f / 3.f;
		cpci.m_shapePhantom = _phantom._as_hkpShapePhantom();
		cpci.m_characterStrength = 5000.0f;
		
		_proxy = hkpCharacterProxy(cpci);

		_proxy.addCharacterProxyListener(InteractionTracking.charProxyListener);

		// adds a ref to _stateMngr
		_characterContext = hkpCharacterContext(
			_stateMngr,
			hkpCharacterStateType.HK_CHARACTER_ON_GROUND
		);
	}

	// Implement NetObj
	void		dispose() {
	}
	// ----


	// Implement GameObj, IPlayerController
	vec3fi		worldPosition() {
		return _coordSys.origin;
	}

	quat		worldRotation() {
		return _coordSys.rotation;
	}
	// ----
	
	
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
	
	void	teleport(vec3fi p) {
		_coordSys.origin = p;
	}
	
	quat	cameraRotation() {
		return _cameraQuat;
	}
	// ----


	// Implements GameObj
	synchronized void update(double seconds) {
		_rotation += _rotationPending;
		if (_rotation.pitch > 90.f) {
			_rotation.pitch = 90.f;
		}
		if (_rotation.pitch < -90.f) {
			_rotation.pitch = -90.f;
		}

		calcRotationAndDirection();

		Phys.world.markForWrite();
		scope (success) Phys.world.unmarkForWrite();

		static hkpCharacterInput input;
		static hkpCharacterOutput output;
		static hkStepInfo si;
		
		//if (0 != _movePending.x || 0 != _movePending.z) {

			if (input._impl is null) {
				input = hkpCharacterInput();
				output = hkpCharacterOutput();
				si = hkStepInfo();
			}

			final gravity = hkVector4(0, -9.81, 0);
			
			{
				input.m_inputLR = -_movePending.x;
				input.m_inputUD = -_movePending.z;

				input.m_wantJump = false;
				input.m_atLadder = false;

				input.m_up = hkVector4.unitY;
				input.m_forward = hkVector4(_direction);

				input.m_stepInfo.m_deltaTime = seconds;
				input.m_stepInfo.m_invDeltaTime = 1.0 / seconds;
				input.m_characterGravity = gravity;
				input.m_velocity = _proxy.getLinearVelocity();
				input.m_position = _proxy.getPosition();

				hkVector4 down = hkVector4(0, -1, 0);
				_proxy.checkSupport(down, input.m_surfaceInfo);
			}

			_characterContext.update(input, output);

			// Feed output from state machine into character proxy
			_proxy.setLinearVelocity(output.m_velocity);

			si.m_deltaTime = seconds;
			si.m_invDeltaTime = 1.0 / seconds;
			_proxy.integrate(si, gravity);
		//}

		_coordSys.origin = vec3fi.from(_proxy.getPosition());

		_movePending = vec3.zero;
		_rotationPending = YawPitch.zero;
	}


	// They are NEVER asleep! - if this func returned true, auth would be given up
	bool isActive() {
		return true;
	}


	void calcRotationAndDirection() {
		_coordSys.rotation = quat.yRotation(_rotation.yaw);
		_cameraQuat = _coordSys.rotation * quat.xRotation(_rotation.pitch);
		_direction = _cameraQuat.xform(-vec3.unitZ);
	}

	

	CoordSys	_coordSys = CoordSys.identity;
	quat		_cameraQuat = quat.identity;
	YawPitch	_rotation = YawPitch.zero;
	vec3		_direction = { x: 0, y: 0, z: -1 };

	vec3		_movePending = vec3.zero;
	YawPitch	_rotationPending = YawPitch.zero;
	

	void storeState(PosRotState* st) {
		st.pos = _coordSys.origin;
		st.vel = vec3.from(_proxy.getLinearVelocity());
		st.yaw = _rotation.yaw;
		st.pitch = _rotation.pitch;
	}
	
	void loadState(PosRotState* st) {
		_coordSys.origin = st.pos;
		_rotation.yaw = st.yaw;
		_rotation.pitch = st.pitch;

		Phys.world.markForWrite();
		final foo = hkVector4(vec3.from(st.pos));
		_proxy.setPosition(foo);
		_proxy.setLinearVelocity(hkVector4(st.vel));
		assert (foo == _proxy.getPosition());
		Phys.world.unmarkForWrite();
	}

	mixin DeclareNetState!(PosRotState);
	mixin MNetObj;
	mixin MGameObj;
}
