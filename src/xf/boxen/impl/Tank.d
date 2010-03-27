module xf.boxen.impl.Tank;

private {
	import xf.Common;

	import xf.boxen.Vehicle;
	
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
	//vec3	angVel = vec3.zero;
	float	leftEng = 0.0f;
	float	rightEng = 0.0f;
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
		/+bs.write(angVel.x);
		bs.write(angVel.y);
		bs.write(angVel.z);+/
		bs.write(leftEng);
		bs.write(rightEng);
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
		/+bs.read(&angVel.x);
		bs.read(&angVel.y);
		bs.read(&angVel.z);+/
		bs.read(&leftEng);
		bs.read(&rightEng);
		bs.read(&isActive);
	}

	void applyDiff(PosRotVelState* a, PosRotVelState* b, float t) {
		pos += (b.pos - a.pos) * t;
		vel += (b.vel - a.vel) * t;
		//angVel += (b.angVel - a.angVel) * t;
		applyQuatDiff(rot, a.rot, b.rot, t);
		leftEng += (b.leftEng - a.leftEng) * t;
		rightEng += (b.rightEng - a.rightEng) * t;
		isActive = b.isActive;
	}

	static float calcDifference(PosRotVelState* a, PosRotVelState* b) {
		return
			(a.pos - b.pos).length
			+ (a.vel - b.vel).length * 0.3f
			+ compareQuats(a.rot, b.rot)
			//+ (a.angVel - b.angVel).length * 0.2f
			+ (a.leftEng - b.leftEng) * 0.2f
			+ (a.rightEng - b.rightEng) * 0.2f
			+ ((a.isActive != b.isActive) ? 0.1f : 0.0f);
	}

	char[] toString() {
		static char[256] buf;
		sprintf(
			buf.ptr, "pos:%f %f %f vel: %f %f %f rot: %f %f %f %f l: %f r: %f",
			pos.tuple,
			vel.tuple,
			rot.xyzw.tuple,
			//angVel.tuple,
			leftEng,
			rightEng
		);
		return fromStringz(buf.ptr);
	}
}


final class Tank : NetObj, IVehicle {
	union {
		struct {
			hkpRigidBody		_hullBody;
			union {
				struct {
					hkpRigidBody[5]	_leftWheels;
					hkpRigidBody[5]	_rightWheels;
				}

				hkpRigidBody[10]	_wheels;
			}
		}

		hkpRigidBody[11]	_allBodies;
	}
	
	hkpMotorAction[5]	_leftWheelActions;
	hkpMotorAction[5]	_rightWheelActions;

	union {
		struct {
			uword[5]	_leftWheelMeshes;
			uword[5]	_rightWheelMeshes;
		}

		uword[10]	_wheelMeshes;
	}

	float	_leftVel = 0.f;
	float	_rightVel = 0.f;


	this(vec3 off, objId id, playerId owner) {
		_coordSys = CoordSys(vec3fi.from(off), quat.identity);
		_id = id;
		
		initPhys(off);
		initializeNetObj(owner);
	}


	private void updateMeshes() {
		final hcs = CoordSys(vec3fi.from(_hullBody.getPosition()), _hullBody.getRotation());

		// the cylinder mesh is standing on its base
		final cs1 = CoordSys(vec3fi.zero, quat.zRotation(90.0f));

		// will need a local transform
		final cs3 = hcs.inverse();

		foreach (wi, wheel; _wheels) {
			uword mi = _wheelMeshes[wi];
			final cs2 = CoordSys(vec3fi.from(wheel.getPosition()), wheel.getRotation());
			xf.boxen.Rendering.meshes.offset[mi] =
				(cs1 in cs2) in cs3;
		}
	}


	private void initPhys(vec3 off) {
		Phys.world.markForWrite();
		scope (success) Phys.world.unmarkForWrite();


		final vec3 hullSize = vec3(1.5f, 1.0f, 2.5f);		// half
		const float wheelRadius = 0.6f;
		final float wheelSuspensionHeight = -hullSize.y - wheelRadius / 2;
		auto hullCenter = off + vec3.unitY * (wheelRadius - wheelSuspensionHeight);

		auto shape = hkpBoxShape(hkVector4(hullSize), 0);

		auto boxInfo = hkpRigidBodyCinfo();
		//boxInfo.m_mass = 3000.0f;
		boxInfo.m_mass = 300.0f;
		auto massProperties = hkpMassProperties();
		hkpInertiaTensorComputer.computeBoxVolumeMassProperties(
				hkVector4(hullSize),
				boxInfo.m_mass,
				massProperties
		);

		int sysGroup = Phys.groupFilter.getNewSystemGroup();

		boxInfo.m_mass = massProperties.m_mass;
		boxInfo.m_centerOfMass = massProperties.m_centerOfMass;
		boxInfo.m_centerOfMass.y -= hullSize.y;
		boxInfo.m_inertiaTensor = massProperties.m_inertiaTensor;
		boxInfo.m_solverDeactivation = SolverDeactivation.SOLVER_DEACTIVATION_MEDIUM;
		boxInfo.m_shape = shape._as_hkpShape;
		boxInfo.m_restitution = 0.5f;
		boxInfo.m_friction = 0.2f;
		boxInfo.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_MOVING;

		const int tankId = 0;
		boxInfo.m_collisionFilterInfo = hkpGroupFilter.calcFilterInfo(tankId, sysGroup);

		boxInfo.m_motionType = MotionType.MOTION_BOX_INERTIA;

		{
			boxInfo.m_position = hkVector4(hullCenter);
			_hullBody = hkpRigidBody(boxInfo);

			addMesh(
				DebugDraw.create(DebugDraw.Prim.Box),
				CoordSys.identity,
				_id,
				vec3.from(hullSize) * 2.0f
			);

			Phys.world.addEntity(_hullBody._as_hkpEntity);
		}

		shape.removeReference();

		float[5] zOff = [-hullSize.z, -hullSize.z/2, 0.f, hullSize.z/2, hullSize.z];
		
		for (int i = 0; i < 5; ++i) {
			createWheel(
					_hullBody,
					hullCenter,
					wheelRadius,
					vec3(hullSize.x + wheelRadius * 0.8f, wheelSuspensionHeight, zOff[i]),
					boxInfo.m_collisionFilterInfo,
					&_rightWheelActions[i],
					&_rightWheels[i],
					&_rightWheelMeshes[i]
			);

			createWheel(
					_hullBody,
					hullCenter,
					wheelRadius,
					vec3(-hullSize.x - wheelRadius * 0.8f, wheelSuspensionHeight, zOff[i]),
					boxInfo.m_collisionFilterInfo,
					&_leftWheelActions[i],
					&_leftWheels[i],
					&_leftWheelMeshes[i]
			);
		}

		_hullBody.removeReference();

		_hullBody.setContactPointCallbackDelay(Phys.contactPersistence);
		_hullBody.setUserData(cast(uword)cast(void*)this);
	}



	private void createWheel(
			hkpRigidBody hull,
			vec3 hullCenter,
			hkReal radius,
			vec3 offset,
			hkUint32 filterInfo,
			hkpMotorAction* resAction,
			hkpRigidBody* resBody,
			uword* resMeshIdx
	) {
		//const wheelMass = 80.0f;
		const wheelMass = 8.0f;

		vec3 relPos = hullCenter + offset;

		auto startAxis = hkVector4(-radius*0.7f, 0.f, 0.f);
		auto endAxis = hkVector4(radius*0.7f, 0.f, 0.f);

		auto info = hkpRigidBodyCinfo();
		auto massProperties = hkpMassProperties();
		hkpInertiaTensorComputer.computeCylinderVolumeMassProperties(startAxis, endAxis, radius, wheelMass, massProperties);

		info.m_mass = massProperties.m_mass;
		info.m_centerOfMass  = massProperties.m_centerOfMass;
		info.m_inertiaTensor = massProperties.m_inertiaTensor;
		info.m_shape = hkpCylinderShape(startAxis, endAxis, radius)._as_hkpShape;
		info.m_position = hkVector4(relPos);
		info.m_motionType  = MotionType.MOTION_BOX_INERTIA;
		info.m_collisionFilterInfo = filterInfo;
		info.m_restitution = 0.0f;
		info.m_friction = 3.0f;
		info.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_MOVING;

		auto wbody = hkpRigidBody(info);
		wbody.setContactPointCallbackDelay(Phys.contactPersistence);
		wbody.setUserData(cast(uword)cast(void*)this);
		
		*resMeshIdx = addMesh(
			DebugDraw.create(DebugDraw.Prim.Cylinder),
			CoordSys.identity,
			_id,
			vec3(radius * 2.0f, (vec3.from(startAxis) - vec3.from(endAxis)).length, radius * 2.0f)
		);

		//addGraphicsCylinder(vec3.from(startAxis), vec3.from(endAxis), radius, wbody, vec3(0.3f, 1.f, 0.2f));

		Phys.world.addEntity(wbody._as_hkpEntity);

		wbody.removeReference();
		info.m_shape.removeReference();

		auto suspension	= hkVector4(vec3.unitY.normalized);
		auto steering	= hkVector4(vec3.unitY.normalized);
		auto axle		= hkVector4(vec3.unitX.normalized);

		auto wheelConstraint = hkpWheelConstraintData();

		wheelConstraint.setInWorldSpace(
				wbody.getTransform(),
				hull.getTransform(),
				wbody.getPosition(),
				axle,
				suspension,
				steering
		);
		
		wheelConstraint.setSuspensionMaxLimit(radius * 0.6); 
		wheelConstraint.setSuspensionMinLimit(-radius * 0.6);
				
		wheelConstraint.setSuspensionStrength(0.007f);
		wheelConstraint.setSuspensionDamping(0.07f);

		Phys.world.createAndAddConstraintInstance(
				wbody,
				hull,
				wheelConstraint._as_hkpConstraintData
		).removeReference();

		auto axis = hkVector4(1.0f, 0.0f, 0.0f);
		hkReal gain = 50.0f;

		*resAction = hkpMotorAction(wbody, axis, 0.f, gain);
		Phys.world.addAction(resAction._as_hkpAction);

		*resBody = wbody;
	}


	// implements IVehicle
	void onPilotLeave() {
		setEngineVelocity(0.0f, 0.0f);
	}


	// implements IVehicle
	void move(float x, float y, float z) {
		float left = z - x;
		float right = z + x;

		setEngineVelocity(left, right);
	}


	// implements IVehicle
	void yawRotate(float angle) {
		// TODO
		//yawRotateTurret(angle);
	}
	

	// implements IVehicle
	void pitchRotate(float angle) {
		// TODO
		//pitchRotateTurret(angle);
	}


	// implements IVehicle
	void shoot() {
		// TODO
		//mainWeapon.shoot();
	}


	// implements IVehicle
	bool getSafeLeavePosition(vec3* pos) {
		// HACK, TODO
		*pos = vec3.from(worldPosition) + vec3(8, 1, 0);
		return true;
	}



	private void setEngineVelocity(float left, float right) {
		_leftVel = left;
		_rightVel = right;

		const float mult = -13.f;

		Phys.world.markForWrite();

		if (left != 0 || right != 0) {
			foreach (entity; _allBodies) {
				entity.activate();
			}
		}

		foreach (wheel; _leftWheelActions) {
			wheel.setSpinRate(left * mult);
		}

		foreach (wheel; _rightWheelActions) {
			wheel.setSpinRate(right * mult);
		}

		Phys.world.unmarkForWrite();
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
			vec3.from(_hullBody.getPosition()), _hullBody.getRotation()
		);
		if (_hullBody.isActive()) {
			_ticksAsleep = 0;
		} else {
			++_ticksAsleep;
		}
		updateMeshes();
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
			_hullBody.getRotation()
		);+/
	}
	

	void storeState(PosRotVelState* st) {
		Phys.world.markForRead();
		st.pos = vec3.from(_hullBody.getPosition());
		st.vel = vec3.from(_hullBody.getLinearVelocity());
		st.rot = _hullBody.getRotation();
		//st.angVel = vec3.from(_hullBody.getAngularVelocity());
		st.isActive = isActive();
		st.leftEng = _leftVel;
		st.rightEng = _rightVel;
		Phys.world.unmarkForRead();
	}
	
	void loadState(PosRotVelState* st) {
		Phys.world.markForWrite();
		_hullBody.setPosition(hkVector4(st.pos));
		_hullBody.setRotation(st.rot);
		_hullBody.setLinearVelocity(hkVector4(st.vel));
		//_hullBody.setAngularVelocity(hkVector4(st.angVel));
		
		if (st.isActive) {
			_hullBody.activate();
			_ticksAsleep = 0;
		} else {
			//_hullBody.deactivate();
			_ticksAsleep = minTicksAsleep;
		}

		setEngineVelocity(st.leftEng, st.rightEng);

		/+hkpEntity_cptr eptr = _hullBody._as_hkpEntity._impl;
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
	mixin MVehicle!(2);
}
