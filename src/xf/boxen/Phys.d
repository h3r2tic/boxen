module xf.boxen.Phys;

private {
	import xf.Common;
	import xf.havok.Havok;
	import xf.core.JobHub;
	import tango.sys.SharedLib;
}



hkpWorld 			world;
hkVisualDebugger	vdb;
hkJobQueue			jobQueue;
hkJobThreadPool		threadPool;
hkpPhysicsContext	context;
hkpGroupFilter		groupFilter;



/**
 * For authority tracking.
 *
 * Objects will be reported to be touching for up to this many ticks after the
 * last contact. This can reduce the number of authority transfer events and
 * callbacks from Havok, but having it too high may cause false auth collisions
 * to be reported and the server to take authority when it doesn't really have to.
 *
 * TODO: The optimal value of this parameter is to be determined.
 *
 * IMPORTANT: Call .setProcessContactCallbackDelay(Phys.contactPersistence) on
 * new hkpRigidBodies, otherwise contact reporting will not work as supposed to.
 * BUG: hide it so the user may not forget to call that func.
 */
enum : ushort { contactPersistence = 3 };


void update(double seconds) {
	world.stepMultithreaded(jobQueue, threadPool, seconds);
	
	context.syncTimers(threadPool);
	vdb.step();
	
	hkMonitorStream.getInstance().reset();
	threadPool.clearTimerData();
}


void initialize(cstring libPath = "HavokC.dll") {
	auto lib = SharedLib.load(libPath);
	
	loadHavok(lib);
	auto initData = initHavok();
	
	jobQueue = initData.jobQueue;
	threadPool = initData.threadPool;
	
	auto worldInfo = hkpWorldCinfo();

	// Set the simulation type of the world to multi-threaded.
	worldInfo.m_simulationType = SimulationType.SIMULATION_TYPE_MULTITHREADED;

	// Flag objects that fall "out of the world" to be automatically removed - just necessary for this physics scene
	worldInfo.m_broadPhaseBorderBehaviour = BroadPhaseBorderBehaviour.BROADPHASE_BORDER_REMOVE_ENTITY;

	world = hkpWorld(worldInfo);
	world.m_contactPointGeneration = ContactPointGeneration.CONTACT_POINT_REJECT_DUBIOUS;

	// When the simulation type is SIMULATION_TYPE_MULTITHREADED, in the debug build, the sdk performs checks
	// to make sure only one thread is modifying the world at once to prevent multithreaded bugs. Each thread
	// must call markForRead / markForWrite before it modifies the world to enable these checks.
	world.markForWrite();

//	world.addCollisionListener((g_colListener = new MyCollisionListener).hk);

	// It's important to register collision agents before adding any entities to the world.
	hkpAgentRegisterUtil.registerAllAgents(world.getCollisionDispatcher());

	// We need to register all modules we will be running multi-threaded with the job queue
	world.registerWithJobQueue(initData.jobQueue);

	groupFilter = hkpGroupFilter();

	world.setCollisionFilter(groupFilter._as_hkpCollisionFilter);

	// Create all the physics rigid bodies
	//g_tank = new Tank;
	//setupPhysics(world);
	
	auto contexts = hkPtrArray();
	
	context = hkpPhysicsContext(); {
		context.registerAllPhysicsProcesses();
		context.addWorld(world);
		contexts.pushBack(context._as_hkProcessContext()._impl);
	}

	//initializeCharacter();

	world.unmarkForWrite();
	
	vdb = hkVisualDebugger(contexts);
	vdb.serve();
	
	//jobHub.addRepeatableJob(&update, 1.0f / timeStep);
}


private {
	alias void delegate(hkpWorldObject, float, hkVector4*, float*) DRayHitHandler;

	__thread RayHitCollector		rayCollector;
	__thread DRayHitHandler*		castRayHandler;
	__thread hkpWorldRayCastInput	castRayInput;

	extern (C) void castRayDRayHitFunc(
		void* ctxPtr,
		hkpWorldObject wo,
		float hitFraction,
		hkVector4* hitNormal,
		float* earlyOutFraction
	) {
		final h = *cast(DRayHitHandler*)castRayHandler;
		h(wo, hitFraction, hitNormal, earlyOutFraction);
	}
}

void castRay(vec3 from, vec3 to, DRayHitHandler handler) {
	assert (castRayHandler is null,
		"castRay is multi-thread safe but not re-entrant within a single thread");
	
	if (rayCollector._impl is null) {
		rayCollector = RayHitCollector(
			DRayHitCollector(cast(void*)&castRayHandler, &castRayDRayHitFunc)
		);
		castRayInput = hkpWorldRayCastInput();
	} else {
		rayCollector.reset();
	}

	.castRayHandler = &handler;
	scope (success) castRayHandler = null;

	castRayInput.m_from = hkVector4(from);
	castRayInput.m_to = hkVector4(to);

	world.castRay(castRayInput, rayCollector._as_hkpRayHitCollector);
}
