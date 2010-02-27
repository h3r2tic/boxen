module xf.havok.HavokDefs;
static import tango.util.container.HashMap;
alias tango.util.container.HashMap.HashMap HashMap;

static import tango.core.Thread;
alias tango.core.Thread.ThreadLocal ThreadLocal;

import xf.omg.core.LinearAlgebra : vec3, quat;


alias size_t	hkUlong;
alias float		hkReal;
alias bool		hkBool;
alias byte		hkInt8;
alias uint		hkUint32;
alias ushort	hkUint16;
alias ulong		hkUint64;

static assert (char.sizeof == hkBool.sizeof);

struct hkVector4 {
	align(16) {
		float x = 0.f, y = 0.f, z = 0.f, w = 0.f;
	}
	
	void setInterpolate4(hkVector4 a, hkVector4 b, hkReal t) {
		x = a.x * (1.f - t) + b.x * t;
		y = a.y * (1.f - t) + b.y * t;
		z = a.z * (1.f - t) + b.z * t;
		w = a.w * (1.f - t) + b.w * t;
	}
	
	static hkVector4 opCall(float x, float y, float z, float w = 0.f) {
		hkVector4 res = void;
		res.x = x;
		res.y = y;
		res.z = z;
		res.w = w;
		return res;		
	}

	static hkVector4 opCall(vec3 v) {
		hkVector4 res = void;
		res.x = v.x;
		res.y = v.y;
		res.z = v.z;
		res.w = 0.f;
		return res;		
	}
}

struct hkMatrix3 {
	hkVector4 m_col0;
	hkVector4 m_col1;
	hkVector4 m_col2;
}


typedef hkMatrix3 hkRotation;

struct hkTransform {
	hkRotation	m_rotation;
	hkVector4	m_translation;
}


alias quat hkQuaternion;


enum hkResult {
	Success = 0,
	Failure = 1
}


enum SimulationType : hkInt8
{
		///
	SIMULATION_TYPE_INVALID,

		/// No continuous simulation is performed
	SIMULATION_TYPE_DISCRETE,

		/// Use this simulation if you want any continuous simulation.
		/// Depending on the hkpEntity->getQualityType(), collisions
		/// are not only performed at 'normal' physical timesteps (called PSI), but
		/// at any time when two objects collide (TOI)
	SIMULATION_TYPE_CONTINUOUS,

		/// Multithreaded continuous simulation.
		/// You must have read the multi threading user guide.<br>
		/// To use this you should call hkpWorld::stepMultithreaded(), see
		/// the hkDefaultPhysicsDemo::stepDemo for an example.
		/// Notes:
		///   - The internal overhead for multi threaded is small and you can expect
		///     good speedups, except:
		///   - solving multiple TOI events can not be done on different threads,
		///     so TOI are solved on a single thread. However the collision detection
		///     for each TOI event can be solver multithreaded (see m_processToisMultithreaded) 
	SIMULATION_TYPE_MULTITHREADED,
}


enum BroadPhaseBorderBehaviour : hkInt8
{
		/// Cause an assert and set the motion type to be fixed (default).
	BROADPHASE_BORDER_ASSERT,

		/// Set the motion type to be fixed and raise a warning.
	BROADPHASE_BORDER_FIX_ENTITY,

		/// Remove the entity from the hkpWorld and raise a warning.
	BROADPHASE_BORDER_REMOVE_ENTITY,

		/// Do not do anything, just continue to work.
		/// If many (>20) objects leave the broadphase,
		/// serious memory and CPU can be wasted.
	BROADPHASE_BORDER_DO_NOTHING,
}


enum MotionType : hkInt8
{
		/// 
	MOTION_INVALID,

		/// A fully-simulated, movable rigid body. At construction time the engine checks
		/// the input inertia and selects MOTION_SPHERE_INERTIA or MOTION_BOX_INERTIA as
		/// appropriate.
	MOTION_DYNAMIC,

		/// Simulation is performed using a sphere inertia tensor. (A multiple of the
		/// Identity matrix). The highest value of the diagonal of the rigid body's
		/// inertia tensor is used as the spherical inertia.
	MOTION_SPHERE_INERTIA,

		/// Simulation is performed using a box inertia tensor. The non-diagonal elements
		/// of the inertia tensor are set to zero. This is slower than the
		/// MOTION_SPHERE_INERTIA motions, however it can produce more accurate results,
		/// especially for long thin objects.
	MOTION_BOX_INERTIA,

		/// Simulation is not performed as a normal rigid body. During a simulation step,
		/// the velocity of the rigid body is used to calculate the new position of the
		/// rigid body, however the velocity is NOT updated. The user can keyframe a rigid
		/// body by setting the velocity of the rigid body to produce the desired keyframe
		/// positions. The hkpKeyFrameUtility class can be used to simply apply keyframes
		/// in this way. The velocity of a keyframed rigid body is NOT changed by the
		/// application of impulses or forces. The keyframed rigid body has an infinite
		/// mass when viewed by the rest of the system.
	MOTION_KEYFRAMED,

		/// This motion type is used for the static elements of a game scene, e.g. the
		/// landscape. Fixed rigid bodies are treated in a special way by the system. They
		/// have the same effect as a rigid body with a motion of type MOTION_KEYFRAMED
		/// and velocity 0, however they are much faster to use, incurring no simulation
		/// overhead, except in collision with moving bodies.
	MOTION_FIXED,

		/// A box inertia motion which is optimized for thin boxes and has less stability problems
	MOTION_THIN_BOX_INERTIA,

		/// A specialized motion used for character controllers
		/// Not currently used
	MOTION_CHARACTER,

		/// 
	MOTION_MAX_ID
}


enum hkpCollidableQualityType : hkInt8
{
		/// Invalid or unassinged type. If you add a hkpRigidBody to the hkpWorld,
		/// this type automatically gets converted to either
		/// HK_COLLIDABLE_QUALITY_FIXED, HK_COLLIDABLE_QUALITY_KEYFRAMED or HK_COLLIDABLE_QUALITY_DEBRIS
	HK_COLLIDABLE_QUALITY_INVALID = -1,

		/// Use this for fixed bodies. 
	HK_COLLIDABLE_QUALITY_FIXED = 0,

		/// Use this for moving objects with infinite mass. 
	HK_COLLIDABLE_QUALITY_KEYFRAMED,

		/// Use this for all your debris objects
	HK_COLLIDABLE_QUALITY_DEBRIS,

		/// Use this for debris objects that should have simplified Toi collisions with fixed/landscape objects.
	HK_COLLIDABLE_QUALITY_DEBRIS_SIMPLE_TOI,

		/// Use this for moving bodies, which should not leave the world, 
		/// but you rather prefer those objects to tunnel through the world than
		/// dropping frames because the engine 
	HK_COLLIDABLE_QUALITY_MOVING,

		/// Use this for all objects, which you cannot afford to tunnel through
		/// the world at all
	HK_COLLIDABLE_QUALITY_CRITICAL,

		/// Use this for very fast objects 
	HK_COLLIDABLE_QUALITY_BULLET,

		/// For user. If you want to use this, you have to modify hkpCollisionDispatcher::initCollisionQualityInfo()
	HK_COLLIDABLE_QUALITY_USER,

		/// Use this for rigid body character controllers
	HK_COLLIDABLE_QUALITY_CHARACTER,

		/// Use this for moving objects with infinite mass which should report contact points and Toi-collisions against all other bodies, including other fixed and keyframed bodies.
		///
		/// Note that only non-Toi contact points are reported in collisions against debris-quality objects.
	HK_COLLIDABLE_QUALITY_KEYFRAMED_REPORTING,

		/// End of this list
	HK_COLLIDABLE_QUALITY_MAX
}


enum SolverDeactivation : hkInt8
{
		/// 
	SOLVER_DEACTIVATION_INVALID,
		/// No solver deactivation
	SOLVER_DEACTIVATION_OFF,
		/// Very conservative deactivation, typically no visible artifacts.
	SOLVER_DEACTIVATION_LOW,
		/// Normal deactivation, no serious visible artifacts in most cases
	SOLVER_DEACTIVATION_MEDIUM,
		/// Fast deactivation, visible artifacts
	SOLVER_DEACTIVATION_HIGH,
		/// Very fast deactivation, visible artifacts
	SOLVER_DEACTIVATION_MAX
}
