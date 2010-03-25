module xf.boxen.impl.DebrisObject;

private {
	import xf.Common;
	
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

	import tango.stdc.stdio;
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
	vec3	pos = vec3.zero;
	vec3	vel	= vec3.zero;
	quat	rot = quat.identity;
	vec3	angVel = vec3.zero;
	bool	isActive = false;

	void serialize(BitStreamWriter* bs) {
		bs.write(pos.x);
		bs.write(pos.y);
		bs.write(pos.z);
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
		bs.read(&pos.x);
		bs.read(&pos.y);
		bs.read(&pos.z);
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

	/+void applyDiff(PosRotVelState* a, PosRotVelState* b, float t) {
		vec3 localPosChange = vec3.from(b.pos - a.pos) * t;
		localPosChange = a.rot.inverse.xform(localPosChange);
		localPosChange = rot.xform(localPosChange);
		pos += vec3fi.from(localPosChange);//(b.pos - a.pos) * t;

		vec3 localVelChange = vec3.from(b.vel - a.vel) * t;
		localVelChange = a.rot.inverse.xform(localVelChange);
		localVelChange = rot.xform(localVelChange);
		vel += localVelChange;

		vec3 angVelChange = vec3.from(b.angVel - a.angVel) * t;
		angVelChange = a.rot.inverse.xform(angVelChange);
		angVelChange = rot.xform(angVelChange);
		angVel += angVelChange;
		
		applyQuatDiff(rot, a.rot, b.rot, t);
		isActive = b.isActive;
	}+/
	

	static float calcDifference(PosRotVelState* a, PosRotVelState* b) {
		return
			(a.pos - b.pos).length
			+ (a.vel - b.vel).length * 0.3f
			+ compareQuats(a.rot, b.rot)
			+ (a.angVel - b.angVel).length * 0.2f
			+ ((a.isActive != b.isActive) ? 0.1f : 0.0f);
	}

	char[] toString() {
		static char[256] buf;
		sprintf(
			buf.ptr, "pos:%f %f %f vel: %f %f %f rot: %f %f %f %f angVel: %f %f %f",
			pos.tuple,
			vel.tuple,
			rot.xyzw.tuple,
			angVel.tuple
		);
		return fromStringz(buf.ptr);
	}
}


final class DebrisObject : NetObj {
	const float size = 1.0f;
	
	this(vec3 off, objId id, playerId owner) {
		_coordSys = CoordSys(vec3fi.from(off), quat.identity);
		_id = id;
		
		initPhys(off);
		initializeNetObj(owner);

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
		boxInfo.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_CRITICAL;
		boxInfo.m_restitution = 0.1f;
		boxInfo.m_friction = 0.9f;
		boxInfo.m_motionType = MotionType.MOTION_BOX_INERTIA;
		boxInfo.m_position = hkVector4(off);

		_rigidBody = hkpRigidBody(boxInfo);
		//boxRigidBody.setUserData(0);
		_rigidBody.setContactPointCallbackDelay(Phys.contactPersistence);

		Phys.world.addEntity(_rigidBody._as_hkpEntity);
		box.removeReference();

		_rigidBody.setUserData(cast(uword)cast(void*)this);
	}


	// Implement NetObj
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
		updateInterpolatedState(	// lags one frame :<
			vec3.from(_rigidBody.getPosition()), _rigidBody.getRotation()
		);
		if (_rigidBody.isActive()) {
			_ticksAsleep = 0;
		} else {
			++_ticksAsleep;
		}
		Phys.world.unmarkForRead();
	}


	bool isActive() {
		return _ticksAsleep < minTicksAsleep;
	}

	

	enum {		minTicksAsleep = 2 }
	int			_ticksAsleep = 0;
	CoordSys	_coordSys = CoordSys.identity;


	void updateInterpolatedState(vec3 pos, quat rot) {
		const float i1 = 0.2;
		const float i2 = 1.0 - i1;
		_coordSys.origin = _coordSys.origin * i1 + vec3fi.from(pos) * i2;
		_coordSys.rotation = quat.slerp(_coordSys.rotation, rot, i2);
			/+vec3fi.from(),
			_rigidBody.getRotation()
		);+/
	}
	

	void storeState(PosRotVelState* st) {
		Phys.world.markForRead();
		st.pos = vec3.from(_rigidBody.getPosition());
		st.vel = vec3.from(_rigidBody.getLinearVelocity());
		st.rot = _rigidBody.getRotation();
		st.angVel = vec3.from(_rigidBody.getAngularVelocity());
		st.isActive = isActive();
		Phys.world.unmarkForRead();
	}
	
	void loadState(PosRotVelState* st) {
		Phys.world.markForWrite();
		_rigidBody.setPosition(hkVector4(st.pos));
		_rigidBody.setRotation(st.rot);
		_rigidBody.setLinearVelocity(hkVector4(st.vel));
		_rigidBody.setAngularVelocity(hkVector4(st.angVel));
		
		if (st.isActive) {
			_rigidBody.activate();
			_ticksAsleep = 0;
		} else {
			//_rigidBody.deactivate();
			_ticksAsleep = minTicksAsleep;
		}

		/+hkpEntity_cptr eptr = _rigidBody._as_hkpEntity._impl;
		/+Phys.world.findInitialContactPoints(
			&eptr,
			1
		);+/
		Phys.world.reintegrateAndRecollideEntities(
			&eptr,
			1,
			ReintegrationRecollideMode.RR_MODE_RECOLLIDE_NARROWPHASE
			| ReintegrationRecollideMode.RR_MODE_REINTEGRATE
		);+/
		
		Phys.world.unmarkForWrite();
	}

	mixin DeclareNetState!(PosRotVelState);
	mixin MNetObj;
	mixin MGameObj;
}
