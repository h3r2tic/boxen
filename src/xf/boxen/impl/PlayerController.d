module xf.boxen.impl.PlayerController;

private {
	import xf.net.NetObj;
	import xf.game.GameObj;
	import xf.game.Defs;
	import xf.utils.BitStream;
	import xf.omg.core.LinearAlgebra;
}



struct PosState {
	vec3 pos;

	void serialize(BitStreamWriter* bs) {
		bs.write(pos.x);
		bs.write(pos.y);
		bs.write(pos.z);
	}
	
	void unserialize(BitStreamReader* bs) {
		bs.read(&pos.x);
		bs.read(&pos.y);
		bs.read(&pos.z);
	}

	void applyDiff(PosState* a, PosState* b, float t) {
		pos += (b.pos - a.pos) * t;
	}

	static float calcDifference(PosState* a, PosState* b) {
		return (a.pos - b.pos).length;
	}
}


final class PlayerController : NetObj {
	this(vec3 off, playerId owner) {
		_pos = off;
		_owner = owner;
		initializeNetObj();
	}

	// Implement NetObj
	playerId	authOwner() {
		return _auth;
	}
	
	void		setAuthOwner(playerId pid) {
		_auth = pid;
	}	
	
	playerId	realOwner() {
		return _owner;
	}
	
	void		setRealOwner(playerId pid) {
		_owner = pid;
	}

	void		dispose() {
	}
	// ----

	// Implements GameObj
	vec3fi		worldPosition() {
		return vec3fi.from(_pos);
	}
	
	
	vec3		_pos;
	playerId	_owner;
	playerId	_auth;

	void storeState(PosState* st) {
		st.pos = _pos;
	}
	
	void loadState(PosState* st) {
		_pos = st.pos;
	}

	mixin DeclareNetState!(PosState);
	mixin MNetObj;
	mixin MGameObj;
}
