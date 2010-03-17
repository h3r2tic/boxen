module xf.game.GameObjMngr;

private {
	import xf.Common;
	import xf.game.Defs;
	import xf.game.GameObj;
	import xf.game.GameObjEvents;
	import GameObjRegistry = xf.game.GameObjRegistry;
	import xf.net.NetObj;
	import NetObjMngr = xf.net.NetObjMngr;
	import xf.utils.Meta : fn2dg;
	import xf.omg.core.LinearAlgebra;
}



// Defined in xf.net.NetObjMngr
private extern (C) extern NetObj[] g_netObjects;


void initialize() {
	version (Client) {
		CreateGameObj.addHandler(fn2dg(&handleCreateGameObj));
	}
}


GameObj getObj(objId id) {
	return g_netObjects[id];
}


version (Server) GameObj createGameObj(cstring typeName, vec3 pos, playerId owner) {	
	final id = NetObjMngr.allocId();
	final type = GameObjRegistry.getGameObjType(typeName);
	final obj = GameObjRegistry
		.create(type, pos, owner);

	obj.overrideId(id);

	NetObjMngr.onNetObjCreated(cast(NetObj)obj);

	CreateGameObj(
		pos,
		id,
		owner,
		type
	).immediate();

	return obj;
}


private {
	version (Client) void handleCreateGameObj(CreateGameObj e) {
		final obj = GameObjRegistry
			.create(e.type, e.pos, e.auth);

		obj.overrideId(e.id);
		NetObjMngr.onNetObjCreated(cast(NetObj)obj);
	}
}
