module Main;

version (StackTracing) import tango.core.tools.TraceExceptions;

import
	xf.Common,
	xf.utils.GfxApp,
	xf.utils.SimpleCamera,
	xf.omg.core.LinearAlgebra,
	xf.omg.core.CoordSys,
	xf.utils.Memory;

import xf.havok.Havok;
import Primitives = xf.gfx.misc.Primitives;

import tango.sys.SharedLib;
import tango.core.Atomic;
import tango.io.Stdout;
import tango.stdc.stdio;


void main() {
	(new TestApp).run;
}


hkpGroupFilter		g_groupFilter;
hkpEntity[]			g_tankEntities;
hkpMotorAction[]	g_leftWheels;
hkpMotorAction[]	g_rightWheels;


const boxSize = hkVector4(1.5f, 1.0f, 0.7f);



struct BoxGraphicsObject {
	vec3	size;		// half-extent for boxes
	vec3	position = vec3.zero;
	quat	rotation = quat.identity;
	vec3	color = vec3.one;
	
	hkpRigidBody entity;
}


struct CylinderGraphicsObject {
	vec3		scale;
	CoordSys	baseCS;
	vec3		position = vec3.zero;
	quat		rotation = quat.identity;
	vec3		color = vec3.one;
	
	hkpRigidBody entity;
}


void addGraphicsBox(vec3 size, hkpRigidBody entity, vec3 color = vec3.one) {
	BoxGraphicsObject o;
	o.size = size;
	o.entity = entity;
	o.color = color;
	g_boxes ~= o;
}


void addGraphicsCylinder(vec3 pointA, vec3 pointB, float radius, hkpRigidBody entity, vec3 color = vec3.one) {
	// the default cylinder is 0,-0.5,0 -> 0,0.5,0, radius = 0.5
	CylinderGraphicsObject o;
	vec3 axis = pointB - pointA;
	o.scale = vec3(radius / 0.5f, axis.length, radius / 0.5f);
	axis.normalize;
	vec3 offset = (pointA + pointB) * 0.5f;
	vec3 I, K;
	axis.formBasis(&I, &K);
	mat3 rotMat = mat3.fromVectors(I, axis, K);
	o.baseCS = CoordSys(vec3fi.from(offset), quat(rotMat));
	o.entity = entity;
	o.color = color;
	
	g_cylinders ~= o;
}


CylinderGraphicsObject[]	g_cylinders;
BoxGraphicsObject[]			g_boxes;


class Tank {
}


Tank				g_tank;
MyCollisionListener	g_colListener;


uint g_simTick;

class MyCollisionListener {
	extern (C) static {
		void cf_added(void* thisptr, hkpEntity a, hkpEntity b, hkUlong* userData) {
			(cast(MyCollisionListener)thisptr).added(a, b, userData);
		}

		void cf_confirmed(void* thisptr, hkpEntity a, hkpEntity b, hkUlong* userData) {
			(cast(MyCollisionListener)thisptr).confirmed(a, b, userData);
		}

		void cf_removed(void* thisptr, hkpEntity a, hkpEntity b, hkUlong* userData) {
			(cast(MyCollisionListener)thisptr).removed(a, b, userData);
		}

		void cf_process(void* thisptr, hkpEntity a, hkpEntity b, hkUlong* userData) {
			(cast(MyCollisionListener)thisptr).process(a, b);
		}
	}
	
	int collisions;
	Atomic!(int) collisionsTS;
	
	struct CPData {
		union {
			struct {
				ushort thread;
				ushort tick;
			}
			
			uint data;
		}
	}
	
	void added(hkpEntity a, hkpEntity b, hkUlong* userData) {
		/+++collisions;
		collisionsTS.increment();
		
		CPData data;
		data.thread = cast(ushort)hkThread.getMyThreadId();
		data.tick = cast(ushort)g_simTick;
		+/
		assert (*userData == 0);
		volatile *userData = 1;
		//*userData = data.data;
		//fprintf(tango.stdc.stdio.stderr, "(%d / %d)\n", collisions, collisionsTS.load());
	}

	void confirmed(hkpEntity a, hkpEntity b, hkUlong* userData) {
		/+++collisions;
		fprintf(tango.stdc.stdio.stderr, "(%d) Collision confirmed between %p and %p\n", collisions, cast(void*)a._impl, cast(void*)b._impl);
		+/
	}
	
	void removed(hkpEntity a, hkpEntity b, hkUlong* userData) {
		/+--collisions;
		collisionsTS.decrement();
		auto tid = hkThread.getMyThreadId();+/
		
		/+CPData data;
		data.data = *userData;+/
		volatile assert (*userData == 1);

		/+fprintf(tango.stdc.stdio.stderr, "g_simTick=%d, data.tick=%d\n", cast(ushort)g_simTick, cast(ushort)data.tick);
		if (cast(ushort)g_simTick == data.tick) {
			if (data.thread != cast(ushort)hkThread.getMyThreadId()) {
				fprintf(tango.stdc.stdio.stderr, "Damn, contact destroyed in other thread than created\n");
				assert (false);
			}
		}+/
		//fprintf(tango.stdc.stdio.stderr, "(%d / %d)\n", collisions, collisionsTS.load());
	}

	void process(hkpEntity a, hkpEntity b) {
		//fprintf(tango.stdc.stdio.stderr, "process\n");
		//fprintf(tango.stdc.stdio.stderr, "Collision processed between %p and %p\n", cast(void*)a._impl, cast(void*)b._impl);
	}
	
	this() {
		DCollisionListener wrapper;
		wrapper.thisptr = cast(void*)this;
		//wrapper.added = &cf_added;
		//wrapper.confirmed = &cf_confirmed;
		//wrapper.removed = &cf_removed;
		wrapper.process = &cf_process;
		this.hk = EntityCollisionListener(wrapper)._as_hkpCollisionListener;
	}
	
	hkpCollisionListener hk;
}


class TestApp : GfxApp {
	hkpWorld			physicsWorld;
	hkVisualDebugger	vdb;
	hkJobQueue			jobQueue;
	hkJobThreadPool		threadPool;
	hkpPhysicsContext	context;

	SimpleCamera		camera;
	Effect				effect;
	Mesh[]				meshes;
	
	
	override void configureWindow(Window wnd) {
		super.configureWindow(wnd);
		wnd.title = "Havok tank demo";
		wnd.interceptCursor = true;
		wnd.showCursor = false;
	}


	override void initialize() {
		camera = new SimpleCamera(vec3(96, 60, 34), 0, 0, window.inputChannel);
		camera.movementSpeed = vec3.one * 40.f;

		effect = renderer.createEffect(
			"basic",
			EffectSource.filePath("basic.cgfx")
		);
		
		effect.useGeometryProgram = false;
		effect.compile();
		
		mat4 viewToClip = mat4.perspective(
			65.0f,		// fov
			cast(float)window.width / window.height,	// aspect
			0.5f,		// near
			1000.0f		// far
		);

		effect.setUniform("viewToClip", viewToClip);
		initializePhysics();
		initializeMeshes();
	}


	void initializeMesh(Mesh* m, vec3[] positions, vec3[] normals, uint[] indices) {
		struct Vertex {
			vec3 p;
			vec3 n;
		}
		Vertex[] vertices;
		vertices.alloc(positions.length);
		foreach (i, p; positions) {
			vertices[i].p = p;
			vertices[i].n = normals[i];
		}

		auto efInst = renderer.instantiateEffect(effect);
		auto vb = renderer.createVertexBuffer(
			BufferUsage.StaticDraw,
			cast(void[])vertices
		);
		
		vertices.free();
		
		efInst.setVarying(
			"VertexProgram.input.position",
			vb,
			VertexAttrib(
				Vertex.init.p.offsetof,
				Vertex.sizeof,
				VertexAttrib.Type.Vec3
			)
		);
		efInst.setVarying(
			"VertexProgram.input.normal",
			vb,
			VertexAttrib(
				Vertex.init.n.offsetof,
				Vertex.sizeof,
				VertexAttrib.Type.Vec3
			)
		);
		
		m.numIndices = indices.length;
		assert (indices.length > 0 && indices.length % 3 == 0);
		
		uword minIdx = uword.max;
		uword maxIdx = uword.min;
		
		foreach (i; indices) {
			if (i < minIdx) minIdx = i;
			if (i > maxIdx) maxIdx = i;
		}

		m.minIndex = minIdx;
		m.maxIndex = maxIdx;
		
		(m.indexBuffer = renderer.createIndexBuffer(
			BufferUsage.StaticDraw,
			indices
		)).dispose();
		
		m.effectInstance = efInst;
	}


	void initializeMeshes() {
		meshes = renderer.createMeshes(2);
		initializeMesh(
			&meshes[0],
			Primitives.Cube.positions,
			Primitives.Cube.normals,
			Primitives.Cube.indices
		);
		initializeMesh(
			&meshes[1],
			Primitives.Cylinder.positions,
			Primitives.Cylinder.normals,
			Primitives.Cylinder.indices
		);
	}
	

	void initializePhysics() {
		auto lib = SharedLib.load("HavokC.dll");
		
		loadHavok(lib);
		auto initData = initHavok();
		
		this.jobQueue = initData.jobQueue;
		this.threadPool = initData.threadPool;
		
		auto worldInfo = hkpWorldCinfo();

		// Set the simulation type of the world to multi-threaded.
		worldInfo.m_simulationType = SimulationType.SIMULATION_TYPE_MULTITHREADED;

		// Flag objects that fall "out of the world" to be automatically removed - just necessary for this physics scene
		worldInfo.m_broadPhaseBorderBehaviour = BroadPhaseBorderBehaviour.BROADPHASE_BORDER_REMOVE_ENTITY;

		this.physicsWorld = hkpWorld(worldInfo);

		// When the simulation type is SIMULATION_TYPE_MULTITHREADED, in the debug build, the sdk performs checks
		// to make sure only one thread is modifying the world at once to prevent multithreaded bugs. Each thread
		// must call markForRead / markForWrite before it modifies the world to enable these checks.
		physicsWorld.markForWrite();

		physicsWorld.addCollisionListener((g_colListener = new MyCollisionListener).hk);

		// Register all collision agents, even though only box - box will be used in this particular example.
		// It's important to register collision agents before adding any entities to the world.
		hkpAgentRegisterUtil.registerAllAgents(physicsWorld.getCollisionDispatcher());

		// We need to register all modules we will be running multi-threaded with the job queue
		physicsWorld.registerWithJobQueue(initData.jobQueue);

		g_groupFilter = hkpGroupFilter();

		physicsWorld.setCollisionFilter(g_groupFilter._as_hkpCollisionFilter);

		// Create all the physics rigid bodies
		g_tank = new Tank;
		setupPhysics(physicsWorld);
		
		auto contexts = hkPtrArray();
		
		this.context = hkpPhysicsContext(); {
			context.registerAllPhysicsProcesses();
			context.addWorld(physicsWorld);
			contexts.pushBack(context._as_hkProcessContext()._impl);
		}

		physicsWorld.unmarkForWrite();
		
		this.vdb = hkVisualDebugger(contexts);
		vdb.serve();
		
		jobHub.addRepeatableJob(&update, 60.f);
	}

	
	void update() {
		++g_simTick;
		
		if (keyboard.keyDown(KeySym.p)) {
			Stdout.formatln("Camera position: {}  orientation: {}", camera.position, camera.orientation);
		}
		
		float left = 0.f;
		float right = 0.f;

		if (keyboard.keyDown(KeySym.Up)) {
			left += 1.f;
			right += 1.f;
		}

		if (keyboard.keyDown(KeySym.Down)) {
		left -= 1.f;
		right -= 1.f;
		}

		if (keyboard.keyDown(KeySym.Right)) {
			left += 0.7f;
			right -= 0.7f;
		}

		if (keyboard.keyDown(KeySym.Left)) {
			left -= 0.7f;
			right += 0.7f;
		}

		if (left > 1.f) left = 1.f;
		if (right > 1.f) right = 1.f;

		if (left < -1.f) left = -1.f;
		if (right < -1.f) right = -1.f;

		const float mult = -13.f;

		physicsWorld.markForWrite();

		if (left != 0 || right != 0) {
			foreach (entity; g_tankEntities) {
				entity.activate();
			}
		}

		foreach (wheel; g_leftWheels) {
			wheel.setSpinRate(left * mult);
		}

		foreach (wheel; g_rightWheels) {
			wheel.setSpinRate(right * mult);
		}

		physicsWorld.unmarkForWrite();

		physicsWorld.markForRead();
		foreach (ref box; g_boxes) {
			box.position = vec3.from(box.entity.getPosition());
			box.rotation = box.entity.getRotation();
		}
		foreach (ref cyl; g_cylinders) {
			cyl.position = vec3.from(cyl.entity.getPosition());
			cyl.rotation = cyl.entity.getRotation();
		}
		physicsWorld.unmarkForRead();

		// ----------------------------------------------------------------

		physicsWorld.stepMultithreaded(jobQueue, threadPool, 1.f / 60);
		
		context.syncTimers(threadPool);
		vdb.step();
		
		hkMonitorStream.getInstance().reset();
		threadPool.clearTimerData();
	}


	override void render() {
		final renderList = renderer.createRenderList();
		assert (renderList !is null);
		scope (success) renderer.disposeRenderList(renderList);


		void drawCube(vec3 position, quat rotation, vec3 size) {
			auto mesh = &meshes[0];
			final bin = renderList.getBin(mesh.effect);
			auto data = bin.add(mesh.effectInstance);
			mesh.toRenderableData(data);
			data.coordSys = CoordSys(vec3fi.from(position), rotation);
			data.scale = size;
		}

		void drawCylinder(vec3 position, quat rotation, vec3 size, CoordSys baseCS) {
			auto mesh = &meshes[1];
			final bin = renderList.getBin(mesh.effect);
			auto data = bin.add(mesh.effectInstance);
			mesh.toRenderableData(data);
			data.coordSys = baseCS in CoordSys(vec3fi.from(position), rotation);
			data.scale = size;
		}


		effect.setUniform("worldToView",
			camera.getMatrix
		);
		
		foreach (ref box; g_boxes) {
			//gl.Color3fv(box.color.ptr);
			drawCube(box.position, box.rotation, box.size);
		}
		
		foreach (ref cyl; g_cylinders) {
			//gl.Color3fv(cyl.color.ptr);
			drawCylinder(cyl.position, cyl.rotation, cyl.scale, cyl.baseCS);
		}

		renderList.sort();
		renderer.framebuffer.settings.clearColorValue[0] = vec4(0.1, 0.1, 0.1, 1.0);
		renderer.clearBuffers();
		renderer.render(renderList);
	}
}


void setupPhysics(hkpWorld physicsWorld) {
	{
		auto groundRadii = hkVector4(70.0f, 2.0f, 140.0f);
		auto shape = hkpBoxShape(groundRadii, 0);
		
		auto ci = hkpRigidBodyCinfo();

		ci.m_shape = shape._as_hkpShape;
		ci.m_motionType = MotionType.MOTION_FIXED;
		ci.m_position = hkVector4(0.0f, -2.0f, 0.0f);
		ci.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_FIXED;
		ci.m_friction = 0.9f;

		auto rb = hkpRigidBody(ci);
		rb.setUserData(cast(size_t)cast(void*)g_tank);
		physicsWorld.addEntity(rb._as_hkpEntity);//.removeReference();
		addGraphicsBox(vec3.from(groundRadii), rb);
		
		shape.removeReference();
	}

	auto groundPos = hkVector4(0.0f, 0.0f, 0.0f);
	hkVector4 posy = groundPos;

	//
	// Create the walls
	//

	int wallHeight = 3;
	int wallWidth  = 6;
	int numWalls = 6;
	hkpBoxShape box = hkpBoxShape(boxSize , 0);

	hkReal deltaZ = 12.0f;
	posy.z = -deltaZ * numWalls * 0.5f;

	for (int y = 0; y < numWalls; ++y)			// first wall
	{
		createBrickWall( physicsWorld, wallHeight, wallWidth, posy, 0.2f, box._as_hkpConvexShape, boxSize );
		posy.z += deltaZ;
	}
	box.removeReference();

	createTank(physicsWorld);
}


void createBrickWall(hkpWorld world, int height, int length, hkVector4 position, hkReal gapWidth, hkpConvexShape box, hkVector4 halfExtents)
{
	hkVector4 posx = position;
	// do a raycast to place the wall
	{
		auto ray = hkpWorldRayCastInput();
		ray.m_from = posx;
		ray.m_to = posx;

		ray.m_from.y += 20.0f;
		ray.m_to.y   -= 20.0f;

		auto result = hkpWorldRayCastOutput();
		world.castRay(ray, result);
		posx.setInterpolate4(ray.m_from, ray.m_to, result.m_hitFraction);
	}
	
	// move the start point
	posx.x -= (gapWidth + 2.0f * halfExtents.x) * length * 0.5f;
	posx.y -= halfExtents.y + box.getRadius();

	hkpEntity_cptr[] entitiesToAdd;

	for (int x = 0; x < length; ++x)		// along the ground
	{
		hkVector4 pos = posx;
		
		for (int ii = 0; ii < height; ++ii)
		{
			pos.y += (halfExtents.y + box.getRadius()) * 2.0f;

			auto boxInfo = hkpRigidBodyCinfo();
			boxInfo.m_mass = 70.0f;
			
			auto massProperties = hkpMassProperties();
			hkpInertiaTensorComputer.computeBoxVolumeMassProperties(halfExtents, boxInfo.m_mass, massProperties);

			boxInfo.m_mass = massProperties.m_mass;
			boxInfo.m_centerOfMass = massProperties.m_centerOfMass;
			boxInfo.m_inertiaTensor = massProperties.m_inertiaTensor;
			boxInfo.m_solverDeactivation = SolverDeactivation.SOLVER_DEACTIVATION_MEDIUM;
			boxInfo.m_shape = box._as_hkpShape;
			boxInfo.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_DEBRIS;
			boxInfo.m_restitution = 0.1f;
			boxInfo.m_friction = 0.9f;

			boxInfo.m_motionType = MotionType.MOTION_BOX_INERTIA;

			{
				boxInfo.m_position = pos;
				auto boxRigidBody = hkpRigidBody(boxInfo);
				boxRigidBody.setUserData(0);
				world.addEntity(boxRigidBody._as_hkpEntity);
				boxRigidBody.removeReference();
				addGraphicsBox(vec3.from(boxSize), boxRigidBody, vec3(.2, .5, 1));
			}

			pos.y += (halfExtents.y + box.getRadius()) * 2.0f;
			pos.x += halfExtents.x * 0.6f;
			{
				boxInfo.m_position = pos;
				auto boxRigidBody = hkpRigidBody(boxInfo);
				boxRigidBody.setUserData(0);
				auto entity = boxRigidBody._as_hkpEntity();
				entitiesToAdd ~= entity._impl;
				addGraphicsBox(vec3.from(boxSize), boxRigidBody, vec3(.2, .5, 1));
			}
			pos.x -= halfExtents.x * 0.6f;
		}
		posx.x += halfExtents.x * 2.0f + gapWidth;
	}
	world.addEntityBatch(entitiesToAdd.ptr, entitiesToAdd.length);

	/+foreach (en; entitiesToAdd) {
		hkpEntity(en).removeReference();
	}+/
}


hkpMotorAction createWheel(
		hkpWorld physicsWorld,
		hkpRigidBody hull,
		vec3 hullCenter,
		hkReal radius,
		vec3 offset,
		hkUint32 filterInfo
) {
	const wheelMass = 80.0f;

	vec3 relPos = hullCenter + offset;

	auto startAxis = hkVector4(-radius*0.7f, 0.f, 0.f);
	auto endAxis = hkVector4(radius*0.7f, 0.f, 0.f);

	auto info = hkpRigidBodyCinfo();
	auto massProperties = hkpMassProperties();
	hkpInertiaTensorComputer.computeCylinderVolumeMassProperties(startAxis, endAxis, radius, wheelMass, massProperties);
	//hkpInertiaTensorComputer::computeSphereVolumeMassProperties (radius, wheelMass, massProperties);

	info.m_mass = massProperties.m_mass;
	info.m_centerOfMass  = massProperties.m_centerOfMass;
	info.m_inertiaTensor = massProperties.m_inertiaTensor;
	info.m_shape = hkpCylinderShape(startAxis, endAxis, radius)._as_hkpShape;
	//info.m_shape = new hkpSphereShape( radius );
	info.m_position = hkVector4(relPos);
	info.m_motionType  = MotionType.MOTION_BOX_INERTIA;
	info.m_collisionFilterInfo = filterInfo;
	info.m_restitution = 0.0f;
	info.m_friction = 3.0f;
	info.m_qualityType = hkpCollidableQualityType.HK_COLLIDABLE_QUALITY_MOVING;

	auto sphereRigidBody = hkpRigidBody(info);
	sphereRigidBody.setProcessContactCallbackDelay(60);
	sphereRigidBody.setUserData(cast(size_t)cast(void*)g_tank);
	addGraphicsCylinder(vec3.from(startAxis), vec3.from(endAxis), radius, sphereRigidBody, vec3(0.3f, 1.f, 0.2f));

	g_tankEntities ~= physicsWorld.addEntity(sphereRigidBody._as_hkpEntity);

	sphereRigidBody.removeReference();
	info.m_shape.removeReference();

	auto suspension	= hkVector4(vec3.unitY.normalized);
	auto steering		= hkVector4(vec3.unitY.normalized);
	auto axle			= hkVector4(vec3.unitX.normalized);

	auto wheelConstraint = hkpWheelConstraintData();

	wheelConstraint.setInWorldSpace(
			sphereRigidBody.getTransform(),
			hull.getTransform(),
			sphereRigidBody.getPosition(),
			axle,
			suspension,
			steering
	);
	
	wheelConstraint.setSuspensionMaxLimit(0.8f); 
	wheelConstraint.setSuspensionMinLimit(-0.8f);
			
	wheelConstraint.setSuspensionStrength(0.007f);
	wheelConstraint.setSuspensionDamping(0.07f);

	physicsWorld.createAndAddConstraintInstance(
			sphereRigidBody,
			hull,
			wheelConstraint._as_hkpConstraintData
	).removeReference();

	auto axis = hkVector4(1.0f, 0.0f, 0.0f);
	//hkReal spinRate = -10.0f;
	hkReal gain = 50.0f;

	auto motorAction = hkpMotorAction(sphereRigidBody, axis, 0.f, gain);
	physicsWorld.addAction(motorAction._as_hkpAction);
	return motorAction;
}


void createTank(hkpWorld physicsWorld) {
	auto hullSize = vec3(3, 2, 5);
	auto hullCenter = vec3(0, 7, 60);
	hkpRigidBody hull;

	auto shape = hkpBoxShape(hkVector4(hullSize), 0);

	auto boxInfo = hkpRigidBodyCinfo();
	boxInfo.m_mass = 3000.0f;
	auto massProperties = hkpMassProperties();
	hkpInertiaTensorComputer.computeBoxVolumeMassProperties(
			hkVector4(hullSize),
			boxInfo.m_mass,
			massProperties
	);

	int sysGroup = g_groupFilter.getNewSystemGroup();

	boxInfo.m_mass = massProperties.m_mass;
	boxInfo.m_centerOfMass = massProperties.m_centerOfMass;
	boxInfo.m_centerOfMass.y -= 2.5f;
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
		auto boxRigidBody = hull = hkpRigidBody(boxInfo);
		boxRigidBody.setProcessContactCallbackDelay(60);
		boxRigidBody.setUserData(cast(size_t)cast(void*)g_tank);
		addGraphicsBox(vec3.from(hullSize), boxRigidBody, vec3(1, .5, .2));
		g_tankEntities ~= physicsWorld.addEntity(boxRigidBody._as_hkpEntity);
	}

	shape.removeReference();

	float[5] zOff = [-hullSize.z, -hullSize.z/2, 0.f, hullSize.z/2, hullSize.z];

	const float wheelRadius = 1.2f;
	
	for (int i = 0; i < 5; ++i) {
		g_rightWheels ~= createWheel(
				physicsWorld,
				hull,
				hullCenter,
				wheelRadius,
				vec3(hullSize.x + wheelRadius * 0.8f, -hullSize.y -wheelRadius/2, zOff[i]),
				boxInfo.m_collisionFilterInfo
		);

		g_leftWheels ~= createWheel(
				physicsWorld,
				hull,
				hullCenter,
				wheelRadius,
				vec3(-hullSize.x - wheelRadius * 0.8f, -hullSize.y-wheelRadius/2, zOff[i]),
				boxInfo.m_collisionFilterInfo
		);
	}

	hull.removeReference();
}
