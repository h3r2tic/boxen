module xf.boxen.impl.DebrisObject;

private {
	import xf.net.NetObj;
	import xf.game.GameObj;
	import xf.game.Defs;
	import xf.utils.BitStream;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;

	import xf.boxen.Rendering;
	import DebugDraw = xf.boxen.DebugDraw;
	import Phys = xf.boxen.Phys;
	import xf.havok.Havok;
}



void applyQuatDiff(ref quat q, ref quat q0, ref quat q1, float t) {
	q = q * (q0.inverse * quat.slerp(q0, q1, t));
	q.normalize;
}


float compareQuats(quat q0, quat q1) {
	auto a = q0.toMatrix!()();
	auto b = q1.toMatrix!()();
	
	float err = 0.f;
	err += 1.f - dot(a.col[0].vec.normalized, b.col[0].vec.normalized);
	err += 1.f - dot(a.col[1].vec.normalized, b.col[1].vec.normalized);
	err += 1.f - dot(a.col[2].vec.normalized, b.col[2].vec.normalized);
	err /= 6.f;
	return err;
}


struct PosRotVelState {
	vec3fi	pos = vec3fi.zero;
	vec3	vel	= vec3.zero;
	quat	rot = quat.identity;
	vec3	angVel = vec3.zero;
	bool	isActive = false;

	void serialize(BitStreamWriter* bs) {
		bs.write(pos.x.store);
		bs.write(pos.y.store);
		bs.write(pos.z.store);
		bs.write(vel.x);
		bs.write(vel.y);
		bs.write(vel.z);
		bs.write(rot.x);
		bs.write(rot.y);
		bs.write(rot.z);
		bs.write(rot.w);
		bs.write(angVel.x);
		bs.write(angVel.y);
		bs.write(angVel.z);
		bs.write(isActive);
	}
	
	void unserialize(BitStreamReader* bs) {
		bs.read(&pos.x.store);
		bs.read(&pos.y.store);
		bs.read(&pos.z.store);
		bs.read(&vel.x);
		bs.read(&vel.y);
		bs.read(&vel.z);
		bs.read(&rot.x);
		bs.read(&rot.y);
		bs.read(&rot.z);
		bs.read(&rot.w);
		bs.read(&angVel.x);
		bs.read(&angVel.y);
		bs.read(&angVel.z);
		bs.read(&isActive);
	}

	void applyDiff(PosRotVelState* a, PosRotVelState* b, float t) {
		pos += (b.pos - a.pos) * t;
		vel += (b.vel - a.vel) * t;
		angVel += (b.angVel - a.angVel) * t;
		applyQuatDiff(rot, a.rot, b.rot, t);
		isActive = b.isActive;
	}

	static float calcDifference(PosRotVelState* a, PosRotVelState* b) {
		return
			vec3.from(a.pos - b.pos).length
			+ (a.vel - b.vel).length * 0.3f
			+ compareQuats(a.rot, b.rot)
			+ (a.angVel - b.angVel).length * 0.2f
			+ (a.isActive != b.isActive) ? 0.1f : 0.0f;
	}
}


final class DebrisObject : NetObj {
	const float size = 1.0f;
	
	this(vec3 off, objId id, playerId owner) {
		_coordSys = CoordSys(vec3fi.from(off), quat.identity);
		_owner = owner;
		_id = id;
		
		initPhys(off);
		initializeNetObj();

		addMesh(
			DebugDraw.create(DebugDraw.Prim.Box),
			CoordSys.identity,
			id,
			vec3.one * size
		);
	}

	hkpRigidBody	_rigidBody;


	private void initPhys(vec3 off) {
		Phys.world.markForWrite();
		scope (success) Phys.world.unmarkForWrite();

		final halfExtents = hkVector4(size * 0.5f, size * 0.5f, size * 0.5f);

		auto boxInfo = hkpRigidBodyCinfo();
		boxInfo.m_mass = 70.0f;
		
		auto massProperties = hkpMassProperties();
		hkpInertiaTensorComputer.computeBoxVolumeMassProperties(
			halfExtents,
			boxInfo.m_mass,
			massProperties
		);

		final box = hkpBoxShape(halfExtents, 0);

		boxInfo.m_mass = massProperties.m_mass;
		boxInfo.m_centerOfMass = massProperties.m_centerOfMass;
		boxInfo.m_inertiaTensor = massProperties.m_inertiaTensor;
		boxInfo.m_solverDeactivation = SolverDeactivation.SOLVER_DEACTIVATION_MEDIUM;
		boxInfo.m_shape = box._as_hkpShape;
		boxInfo.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_DEBRIS;
		boxInfo.m_restitution = 0.1f;
		boxInfo.m_friction = 0.9f;
		boxInfo.m_motionType = MotionType.MOTION_BOX_INERTIA;
		boxInfo.m_position = hkVector4(off);

		_rigidBody = hkpRigidBody(boxInfo);
		//boxRigidBody.setUserData(0);

		Phys.world.addEntity(_rigidBody._as_hkpEntity);
		box.removeReference();
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


	// Implement GameObj
	vec3fi		worldPosition() {
		return _coordSys.origin;
	}

	quat		worldRotation() {
		return _coordSys.rotation;
	}
	// ----
	
	
	// Implements GameObj
	synchronized void update(double seconds) {
		Phys.world.markForRead();
		_coordSys = CoordSys(		// lags one frame :S
			vec3fi.from(_rigidBody.getPosition()),
			_rigidBody.getRotation()
		);
		Phys.world.unmarkForRead();
	}

	

	CoordSys	_coordSys = CoordSys.identity;
	
	playerId	_owner;
	playerId	_auth;

	void storeState(PosRotVelState* st) {
		Phys.world.markForRead();
		st.pos = vec3fi.from(_rigidBody.getPosition());
		st.vel = vec3.from(_rigidBody.getLinearVelocity());
		st.rot = _rigidBody.getRotation();
		st.angVel = vec3.from(_rigidBody.getAngularVelocity());
		st.isActive = _rigidBody.isActive();
		Phys.world.unmarkForRead();
	}
	
	void loadState(PosRotVelState* st) {
		_coordSys.origin = st.pos;
		_coordSys.rotation = st.rot;

		Phys.world.markForWrite();
		_rigidBody.setPosition(hkVector4(vec3.from(st.pos)));
		_rigidBody.setLinearVelocity(hkVector4(st.vel));
		_rigidBody.setRotation(st.rot);
		_rigidBody.setAngularVelocity(hkVector4(st.angVel));
		
		if (st.isActive) {
			_rigidBody.activate();
		} else {
			_rigidBody.deactivate();
		}
		
		Phys.world.unmarkForWrite();
	}

	mixin DeclareNetState!(PosRotVelState);
	mixin MNetObj;
	mixin MGameObj;
}
