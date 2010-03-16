module xf.game.GameObjEvents;

private {
	import xf.game.GameObj;
	import xf.game.Event;
	import xf.game.Defs;
	import xf.omg.core.LinearAlgebra;
}



class CreateGameObj : Order {
	vec3					pos;
	objId				id;
	playerId			auth;
	GameObjType	type;
	mixin				MEvent;
}


class OverrideAuthority : Order {
	objId		obj;
	playerId	player;
	mixin		MEvent;
}


// temporary authority request
class RequestAuthority : Wish {
	objId	obj;
	mixin	MEvent;
}


// temporary authority release
class GiveUpAuthority : Wish {
	objId	obj;
	mixin	MEvent;
}


// ownership change
class AcquireObject : Wish {
	objId	obj;
	mixin 	MEvent;
}


// ownership release
class ReleaseObject : Wish {
	objId	obj;
	mixin	MEvent;
}


class RefuseObjectAcquisition : Order {
	objId	obj;
	mixin	MEvent;
}


class ObjectOwnershipChange : Order {
	objId		obj;
	playerId	player;
	mixin		MEvent;
}
