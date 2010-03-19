#include <Common/Base/hkBase.h>
#include <Common/Base/hkBase.h>
#include <Common/Base/System/hkBaseSystem.h>
#include <Common/Base/Memory/hkThreadMemory.h>
#include <Common/Base/Memory/Memory/Pool/hkPoolMemory.h>
#include <Common/Base/System/Error/hkDefaultError.h>
#include <Common/Base/Monitor/hkMonitorStream.h>

// Dynamics includes
#include <Physics/Collide/hkpCollide.h>										
#include <Physics/Collide/Agent/ConvexAgent/SphereBox/hkpSphereBoxAgent.h>	
#include <Physics/Collide/Shape/Convex/Box/hkpBoxShape.h>					
#include <Physics/Collide/Shape/Convex/Cylinder/hkpCylinderShape.h>					
#include <Physics/Collide/Shape/Convex/Capsule/hkpCapsuleShape.h>
#include <Physics/Collide/Shape/Convex/Sphere/hkpSphereShape.h>				
#include <Physics/Collide/Dispatch/hkpAgentRegisterUtil.h>					

#include <Physics/Dynamics/Collide/hkpCollisionListener.h>
#include <Physics/Dynamics/Phantom/hkpSimpleShapePhantom.h>
#include <Physics/ConstraintSolver/Simplex/hkpSimplexSolver.h>

#include <Physics/Utilities/CharacterControl/hkpCharacterControl.h>
#include <Physics/Utilities/CharacterControl/CharacterProxy/hkpCharacterProxy.h>
#include <Physics/Utilities/CharacterControl/StateMachine/hkpDefaultCharacterStates.h>


#include <Physics/Dynamics/Constraint/Bilateral/Wheel/hkpWheelConstraintData.h>
#include <Physics/Utilities/Actions/Motor/hkpMotorAction.h>
#include <Physics/Collide/Filter/Group/hkpGroupFilter.h>



#include <Physics/Collide/Query/CastUtil/hkpWorldRayCastInput.h>			
#include <Physics/Collide/Query/CastUtil/hkpWorldRayCastOutput.h>			

#include <Physics/Dynamics/World/hkpWorld.h>								
#include <Physics/Dynamics/Entity/hkpRigidBody.h>							
#include <Physics/Utilities/Dynamics/Inertia/hkpInertiaTensorComputer.h>	

#include <Common/Base/Thread/Job/ThreadPool/Cpu/hkCpuJobThreadPool.h>
#include <Common/Base/Thread/Job/ThreadPool/Spu/hkSpuJobThreadPool.h>
#include <Common/Base/Thread/JobQueue/hkJobQueue.h>

// Visual Debugger includes
#include <Common/Visualize/hkVisualDebugger.h>
#include <Physics/Utilities/VisualDebugger/hkpPhysicsContext.h>				

// Keycode
#include <Common/Base/keycode.cxx>

// Classlists
#define INCLUDE_HAVOK_PHYSICS_CLASSES
#define HK_CLASSES_FILE <Common/Serialize/Classlist/hkClasses.h>
#include <Common/Serialize/Util/hkBuiltinTypeRegistry.cxx>

// Generate a custom list to trim memory requirements
#define HK_COMPAT_FILE <Common/Compat/hkCompatVersions.h>
#include <Common/Compat/hkCompat_None.cxx>

// --------------------------------------------------------------------------------------------------------------------------------

#define HKCAPI __declspec(dllexport)
#include <cassert>

// --------------------------------------------------------------------------------------------------------------------------------

#include <cstdio>
static void HK_CALL errorReport(const char* msg, void*)
{
	printf("%s", msg);
}

struct HavokInitData {
	hkJobThreadPool*	threadPool()	{ return m_threadPool; }
	hkJobQueue*			jobQueue()		{ return m_jobQueue; }

	hkJobThreadPool*	m_threadPool;
	hkJobQueue*			m_jobQueue;
};

HavokInitData* initHavok() {
	HavokInitData* initData = new HavokInitData;

#if !defined(HK_PLATFORM_WIN32)
	extern void initPlatform();
	initPlatform();
#endif


	//
	// Initialize the base system including our memory system
	//

	hkPoolMemory* memoryManager = new hkPoolMemory();
	hkThreadMemory* threadMemory = new hkThreadMemory(memoryManager);
	hkBaseSystem::init( memoryManager, threadMemory, errorReport );
	memoryManager->removeReference();

	// We now initialize the stack area to 100k (fast temporary memory to be used by the engine).
	char* stackBuffer;
	{
		int stackSize = 0x100000;
		stackBuffer = hkAllocate<char>( stackSize, HK_MEMORY_CLASS_BASE);
		hkThreadMemory::getInstance().setStackArea( stackBuffer, stackSize);
	}


	//
	// Initialize the multi-threading classes, hkJobQueue, and hkJobThreadPool
	//

	// They can be used for all Havok multithreading tasks. In this exmaple we only show how to use
	// them for physics, but you can reference other multithreading demos in the demo framework
	// to see how to multithread other products. The model of usage is the same as for physics.
	// The hkThreadpool has a specified number of threads that can run Havok jobs.  These can work
	// alongside the main thread to perform any Havok multi-threadable computations.
	// The model for running Havok tasks in Spus and in auxilary threads is identical.  It is encapsulated in the
	// class hkJobThreadPool.  On PLAYSTATION(R)3 we initialize the SPU version of this class, which is simply a SPURS taskset.
	// On other multi-threaded platforms we initialize the CPU version of this class, hkCpuJobThreadPool, which creates a pool of threads
	// that run in exactly the same way.  On the PLAYSTATION(R)3 we could also create a hkCpuJobThreadPool.  However, it is only
	// necessary (and advisable) to use one Havok PPU thread for maximum efficiency. In this case we simply use this main thread
	// for this purpose, and so do not create a hkCpuJobThreadPool.
	hkJobThreadPool* threadPool;

	// We can cap the number of threads used - here we use the maximum for whatever multithreaded platform we are running on. This variable is
	// set in the following code sections.
	int totalNumThreadsUsed;

	// Get the number of physical threads available on the system
	hkHardwareInfo hwInfo;
	hkGetHardwareInfo(hwInfo);
	totalNumThreadsUsed = hwInfo.m_numThreads;

	// We use one less than this for our thread pool, because we must also use this thread for our simulation
	hkCpuJobThreadPoolCinfo threadPoolCinfo;
	threadPoolCinfo.m_numThreads = totalNumThreadsUsed - 1;

	// This line enables timers collection, by allocating 200 Kb per thread.  If you leave this at its default (0),
	// timer collection will not be enabled.
	threadPoolCinfo.m_timerBufferPerThreadAllocation = 200000;
	threadPool = new hkCpuJobThreadPool( threadPoolCinfo );

	// We also need to create a Job queue. This job queue will be used by all Havok modules to run multithreaded work.
	// Here we only use it for physics.
	hkJobQueueCinfo info;
	info.m_jobQueueHwSetup.m_numCpuThreads = totalNumThreadsUsed;
	hkJobQueue* jobQueue = new hkJobQueue(info);

	//
	// Enable monitors for this thread.
	//

	// Monitors have been enabled for thread pool threads already (see above comment).
	hkMonitorStream::getInstance().resize(200000);

	initData->m_threadPool = threadPool;
	initData->m_jobQueue = jobQueue;

	return initData;
}


extern "C" {
	typedef void (*DEntityCollisionFunc)(void*, const hkpEntity*, const hkpEntity*, hkUlong*);
}


struct DCollisionListener {
	void* thisptr;
	DEntityCollisionFunc added;
	DEntityCollisionFunc confirmed;
	DEntityCollisionFunc removed;
	DEntityCollisionFunc process;

	DCollisionListener() :
		thisptr(NULL),
		added(NULL),
		confirmed(NULL),
		removed(NULL),
		process(NULL)
	{}
};


class EntityCollisionListener : public hkpCollisionListener {
public:
	DCollisionListener	m_dListener;


	EntityCollisionListener(const DCollisionListener& dListener) :
		m_dListener(dListener)
	{}


	void contactPointAddedCallback (hkpContactPointAddedEvent &event) {
		if (m_dListener.added) {
			const hkpEntity *const e1 = static_cast<hkpEntity*>(event.m_bodyA->getRootCollidable()->getOwner());
			if (e1) {
				const hkpEntity *const e2 = static_cast<hkpEntity*>(event.m_bodyB->getRootCollidable()->getOwner());
				if (e2 && e1->getUserData() != e2->getUserData()) {
					hkUlong userData = event.m_contactPointProperties->getUserData(); 
					hkUlong orig = userData;
					m_dListener.added(m_dListener.thisptr, e1, e2, &userData);
					if (userData != orig) {
						event.m_contactPointProperties->setUserData(userData);
					}
				}
			}
		}
	}

	void contactPointConfirmedCallback (hkpContactPointConfirmedEvent &event) {
		if (m_dListener.confirmed) {
			const hkpEntity *const e1 = static_cast<hkpEntity*>(event.m_collidableA->getOwner());
			if (e1) {
				const hkpEntity *const e2 = static_cast<hkpEntity*>(event.m_collidableB->getOwner());
				if (e2 && e1->getUserData() != e2->getUserData()) {
					hkUlong userData = event.m_contactPointProperties->getUserData(); 
					hkUlong orig = userData;
					m_dListener.confirmed(m_dListener.thisptr, e1, e2, &userData);
					if (userData != orig) {
						event.m_contactPointProperties->setUserData(userData);
					}
				}
			}
		}
	}

	void contactPointRemovedCallback (hkpContactPointRemovedEvent &event) {
		if (m_dListener.removed) {
			const hkpEntity *const e1 = event.m_entityA;
			if (e1) {
				const hkpEntity *const e2 = event.m_entityB;
				if (e2 && e1->getUserData() != e2->getUserData()) {
					hkUlong userData = event.m_contactPointProperties->getUserData(); 
					hkUlong orig = userData;
					m_dListener.removed(m_dListener.thisptr, e1, e2, &userData);
					if (userData != orig) {
						event.m_contactPointProperties->setUserData(userData);
					}
				}
			}
		}
	}

	void contactProcessCallback (hkpContactProcessEvent &event) {
		if (m_dListener.process) {
			const hkpEntity *const e1 = static_cast<hkpEntity*>(event.m_collidableA->getOwner());
			if (e1) {
				const hkpEntity *const e2 = static_cast<hkpEntity*>(event.m_collidableB->getOwner());
				if (e2 && e1->getUserData() != e2->getUserData()) {
					hkUlong userData;// = event.m_contactPointProperties.getUserData(); 
					//hkUlong orig = userData;
					m_dListener.process(m_dListener.thisptr, e1, e2, &userData);
					/*if (userData != orig) {
						event.m_contactPointProperties.setUserData(userData);
					}*/
				}
			}
		}
	}
};


extern "C"
{
	#include "HavokC.cpp.i"
}

// --------------------------------------------------------------------------------------------------------------------------------
