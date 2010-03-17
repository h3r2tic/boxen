module xf.boxen.Events;

private {
	import xf.game.GameObj;
	import xf.game.Event;
	import xf.game.Defs;
	import xf.net.LocalNetObj;
	import xf.omg.core.LinearAlgebra;
}



class AssignController : Order {
	objId	id;
	mixin	MEvent;
}


class InputWish : Wish {
	enum : ubyte {
		Shoot = 0b1,
		Use = 0b10
	}
	
	byte	thrust;
	byte	strafe;
	vec2	rot = vec2.zero;
	ubyte	action;
	
	mixin	MEvent;


	override bool logged() {
		return true;
	}
	
	override bool replayed() {
		return true;
	}
}


class CreateProjectileOrder : Order {
	localNetObjId	objId;
	playerId		creator;
	vec3			pos;
	vec3			vel;
	vec4			col;
	float			size;
	float			damage;
	float			explosionRadius;
	float			life;
	mixin			MEvent;
}


class CreateProjectile : Local {
	playerId	creator;
	vec3		pos;
	vec3		vel;
	vec4		col;
	float		size;
	float		damage;
	float		explosionRadius;
	float		life;
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
	vec3		pos;
	float		damage;
	float		radius;
	playerId	creator;
	mixin		MEvent;
}


class EnterVehicleRequest : Wish {
	objId	obj;
	byte	seat = -1;		// -1 == first free
	mixin	MEvent;
}


class LeaveVehicleRequest : Wish {
	mixin MEvent;
}


class EnterVehicleOrder : Order {
	playerId	player;
	objId		obj;
	byte		seat;
	mixin		MEvent;
}


class LeaveVehicleOrder : Order {
	playerId	player;
	vec3		pos;
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
	vec3		pos;
	mixin		MEvent;
}


class DestroyWreck : Order {
	objId		obj;
	playerId	attacker;
	mixin		MEvent;
}
