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
	void	move(vec3);
	void	yawRotate(float);
	void	pitchRotate(float);
	vec3fi	worldPosition();
	quat	worldRotation();
	void	teleport(vec3fi);
	quat	cameraRotation();
	/+abstract ITouchTracker controllerTouchTracker();
	abstract void shoot();+/
}
