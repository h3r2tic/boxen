module xf.game.LoginEvents;

private {
	import xf.game.Event;
	import xf.game.Defs;
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
	//objId		ctrlId;
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
	//objId		ctrlId;
	mixin		MEvent;

	override bool strictTiming() {
		return true;
	}
}


class PlayerLogout : Order {
	playerId	pid;
	mixin		MEvent;
}
