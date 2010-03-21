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
