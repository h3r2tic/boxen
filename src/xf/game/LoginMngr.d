module xf.game.LoginMngr;

private {
	import xf.Common;
	import xf.game.Defs;
	import xf.game.Event;
	import xf.game.LoginEvents;
	import xf.game.GameObjEvents;
	import xf.game.Log : log = gameLog, error = gameError;
	import xf.net.ControlEvents;
	import NetObjMngr = xf.net.NetObjMngr;
	import xf.net.NetObj;
	import xf.utils.Meta : fn2dg;
	import xf.omg.core.LinearAlgebra;
}


// Managed by xf.net.NetObjMngr
private extern (C) extern NetObj[] g_netObjects;

version (Client) {
	// Managed by xf.net.GameClient
	private extern (C) extern playerId g_localPlayerId;
}


struct PlayerInfo {
static:
	cstring[maxPlayers]	nick;
	bool[maxPlayers]	loggedIn;


	void reset(playerId pid) {
		loggedIn[pid] = false;
		nick[pid] = null;
	}
}


void initialize() {
	version (Server) {
		LoginRequest.addHandler(fn2dg(&handleLoginRequest));
		/+RequestAuthority.addHandler(&handle);
		GiveUpAuthority.addHandler(&handle);
		AcquireObject.addHandler(&handle);
		ReleaseObject.addHandler(&handle);+/
	}

	version (Client) {
		PlayerLogin.addHandler(fn2dg(&handlePlayerLogin));
		LoginAccepted.addHandler(fn2dg(&handleLoginAccepted));
		/+OverrideAuthority.addHandler(&handle);
		ObjectOwnershipChange.addHandler(&handle);
		RefuseObjectAcquisition.addHandler(&handle);+/
	}
	
	PlayerLogout.addHandler(fn2dg(&handlePlayerLogout));

	/+phys = new PhysicsEngine;
	scene = phys.createScene;
	scene.setGravity(vec3(0, -9.81 * 10, 0));		// multiplied by 10 cause we operate on decimeters
	scene.setTimestep(0, 0, TimestepMode.Variable);
	timeHub.addTracker(this);
	timeHub.overrideTicksPerSecond = 60;		// don't strain the physics engine/cpu :P
	+/
}



bool nickLoggedIn(cstring nick) {
	foreach (pid, n; PlayerInfo.nick) {
		if (PlayerInfo.loggedIn[pid] && nick == n) {
			return true;
		}
	}
	return false;
}


bool playerLoggedIn(playerId id) {
	return id < maxPlayers && PlayerInfo.loggedIn[id];
}


private {
		// ----

		// TODO



	/+protected abstract IPlayer createPlayerData(
			playerId pid,
			cstring nick,
			objId ctrlId
	);+/


	version (Server) void handleLoginRequest(LoginRequest e) {
		final filter = (playerId pid) {
			return pid == e.wishOrigin;
		};

		log.info("Handling a login request from player \"{}\".", e.nick);
		
		if (nickLoggedIn(e.nick)) {
			LoginRejected("nickname in use").filter(filter).immediate;
		} else {
			log.info("Login request accepted");
			
			objId ctrlId = NetObjMngr.allocId();//gameInterface.genObjId();
			//auto pdata = createPlayerData(e.wishOrigin, e.nick, ctrlId);

			PlayerInfo.loggedIn[e.wishOrigin] = true;
			PlayerInfo.nick[e.wishOrigin] = e.nick.dup;
			
			// must be before the other events so the peer knows localPlayerId
			LoginAccepted(e.wishOrigin, e.nick/+, ctrlId+/).filter(filter).immediate;

			for (playerId rpid = 0; rpid < maxPlayers; ++rpid) {
				if (rpid is e.wishOrigin) continue;
				if (!PlayerInfo.loggedIn[rpid]) continue;

				PlayerLogin(
					rpid,
					PlayerInfo.nick[rpid]
				).filter(filter).immediate;
/+				
				if (ctrl.authOwner != rpid) {
					OverrideAuthority(ctrl.id, ctrl.authOwner).immediate;
				}+/
			}

			PlayerLogin(e.wishOrigin, e.nick/+, ctrlId+/).filter((playerId pid) { return pid != e.wishOrigin; }).immediate;
			
			foreach (o; g_netObjects) {
				if (o is null) continue;
				
				log.trace(
					"Ordering the client to build an object of type {}",
					o.gameObjType
				);
				
				CreateGameObj(
					vec3.from(o.worldPosition),
					o.id,
					o.authOwner,
					o.gameObjType
				).filter(filter).immediate;
			}

			// TODO
			//serverOnPlayerLoginAccepted(e.wishOrigin);
		}
	}


	version (Client) void handleLoginAccepted(LoginAccepted e) {
		log.info("It's time to kick ass and chew bubble gum!");
		
		// bind local wishes to the local player
		g_localPlayerId = e.pid;

		// TODO
		//initInput();

		/+with (createPlayerData(e.pid, e.nick, e.ctrlId)) {
			controller.overridePredicted(true);
		}+/
	}


	version (Client) void handlePlayerLogin(PlayerLogin e) {
		assert (false, "TODO");
		//createPlayerData(e.pid, e.nick, e.ctrlId);
	}


	void handlePlayerLogout(PlayerLogout e) {
		assert (playerLoggedIn(e.pid));		// TODO: err

		// TODO
		//destroyNetObj(PlayerInfo.controller[e.pid]);
		PlayerInfo.reset(e.pid);
	}


	protected void destroyNetObj(NetObj o) {
		version (Server) {
			DestroyObject(o.id).immediate;
			o.netObjScheduleForDeletion();
		}
	}
}
