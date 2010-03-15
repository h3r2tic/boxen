module xf.game.GameObj;

private {
	import xf.game.Defs;
	import xf.omg.core.LinearAlgebra;
}



typedef ushort GameObjType = ushort.max;

interface GameObj {
	objId		id();
	void		overrideId(objId);
	vec3fi		worldPosition();
	GameObjType	gameObjType();
}
