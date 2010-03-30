module xf.boxen.impl.TestLevel;

private {
	import xf.core.Registry;
	import xf.boxen.model.ILevel;
	import Phys = xf.boxen.Phys;
	import xf.havok.Havok;
}



class TestLevel : ILevel {
	mixin (Implements("ILevel"));
	
	this() {
		createGroundPlane();
	}

	void update(double seconds) {
	}
}


private {
	void createGroundPlane() {
		Phys.world.markForWrite();
		scope (success) Phys.world.unmarkForWrite();
		
		// half-extents
		auto groundRadii = hkVector4(200.0f, 2.0f, 200.0f);
		auto shape = hkpBoxShape(groundRadii, 0);
		
		auto ci = hkpRigidBodyCinfo();

		ci.m_shape = shape._as_hkpShape;
		ci.m_motionType = MotionType.MOTION_FIXED;
		ci.m_position = hkVector4(0.0f, -2.0f, 0.0f);
		ci.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_FIXED;
		ci.m_friction = 0.9f;
		ci.m_restitution = 0.1f;

		auto rb = hkpRigidBody(ci);
		//rb.setUserData(cast(size_t)cast(void*)g_tank);
		Phys.world.addEntity(rb._as_hkpEntity);//.removeReference();
		shape.removeReference();
	}
}
