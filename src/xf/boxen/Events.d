module xf.boxen.Events;

private {
	import xf.game.GameObj;
	import xf.game.Event;
	import xf.game.Misc;
	import xf.net.LocalNetObj;
	import xf.omg.core.LinearAlgebra;
}



class JoinGame : Wish {
	mixin MEvent;
}


class LoginRequest : Wish {
	char[]	nick;
	mixin	MEvent;
}


class LoginAccepted : Order {
	playerId	pid;
	char[]		nick;
	objId		ctrlId;
	mixin		MEvent;

	override bool strictTiming() {
		return true;
	}
}


class LoginRejected : Order {
	char[]	reason;
	mixin	MEvent;
}


class PlayerLogin : Order {
	playerId	pid;
	char[]		nick;
	objId		ctrlId;
	mixin		MEvent;

	override bool strictTiming() {
		return true;
	}
}


class PlayerLogout : Order {
	playerId	pid;
	mixin		MEvent;
}


class InputWish : Wish {
	enum : ubyte {
		Shoot = 0b1,
		Use = 0b10
	}
	
	byte		thrust;
	byte		strafe;
	vec2		rot = vec2.zero;
	ubyte	action;
	mixin	MEvent;


	override bool logged() {
		return true;
	}
	
	override bool replayed() {
		return true;
	}
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


class CreateProjectileOrder : Order {
	localNetObjId	objId;
	playerId		creator;
	vec3				pos;
	vec3				vel;
	vec4				col;
	float				size;
	float				damage;
	float				explosionRadius;
	float				life;
	mixin			MEvent;
}


class CreateProjectile : Local {
	playerId	creator;
	vec3			pos;
	vec3			vel;
	vec4			col;
	float			size;
	float			damage;
	float			explosionRadius;
	float			life;
	mixin		MEvent;
	
	
	override void rollback() {
		if (created) {
			delete created;
		}
	}	
	Object created;
}


class DestroyLocalNetObj : Order {
	localNetObjId	objId;
	mixin			MEvent;
}


class CreateExplosion : Order {
	vec3			pos;
	float			damage;
	float			radius;
	playerId	creator;
	mixin		MEvent;
}


class EnterVehicleRequest : Wish {
	objId	obj;
	byte		seat = -1;		// -1 == first free
	mixin	MEvent;
}


class LeaveVehicleRequest : Wish {
	mixin MEvent;
}


class EnterVehicleOrder : Order {
	playerId	player;
	objId		obj;
	byte			seat;
	mixin		MEvent;
}


class LeaveVehicleOrder : Order {
	playerId	player;
	vec3			pos;
	mixin		MEvent;
}


class DealDamage : Order {
	objId		obj;
	int			amount;
	playerId	attacker;
	mixin		MEvent;
}


class WreckObject : Order {
	objId		obj;
	playerId	attacker;
	mixin		MEvent;
}


class KillPlayer : Order {
	playerId	player;
	playerId	killer;
	mixin		MEvent;
}


class NotifyPlayerScore : Order {
	playerId	player;
	int			kills;
	int			deaths;
	mixin		MEvent;
}


class RespawnPlayer : Order {
	playerId	player;
	vec3			pos;
	mixin		MEvent;
}


class DestroyWreck : Order {
	objId		obj;
	playerId	attacker;
	mixin		MEvent;
}
