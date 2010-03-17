module xf.boxen.model.IPlayerController;

private {
	//import xf.boxen.model.ITouchTracker;
	//import xf.net.NetObj;
	//import xf.boxen.model.IGameObj;
	//import xf.boxen.GameObj;
	//import xf.phys.Entity : IEntity;
	//import xf.net.NetObj : NetObjBase;

	import xf.omg.core.LinearAlgebra;
}



interface IPlayerController  {
/+	abstract void createPhysics();
	abstract void dispose();
	abstract float radius();+/
	abstract void	move(vec3);
	abstract void	yawRotate(float);
	abstract void	pitchRotate(float);
	abstract vec3	worldDirection();
	abstract vec3fi	worldPosition();
	abstract void	teleport(vec3fi);
	abstract quat	rotationQuat();
	/+abstract ITouchTracker controllerTouchTracker();
	abstract void shoot();+/
}
