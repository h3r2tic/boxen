module xf.game.GameObj;

private {
	import xf.game.Defs;
	import xf.omg.core.LinearAlgebra;
}



typedef ushort GameObjType = ushort.max;

interface GameObj {
	// Covered by MGameObj
		GameObjType	gameObjType();
		objId		id();
		void		overrideId(objId);
	// ----

	vec3fi	worldPosition();
	quat	worldRotation();
	void	update(double seconds);
}

template MGameObj() {
	final GameObjType gameObjType() {
		return _gameObjType;
	}
	
	static void overrideGameObjType(GameObjType t) {
		_gameObjType = t;
	}

	final objId id() {
		return _id;
	}

	final void overrideId(objId i) {
		_id = i;
	}

	private static {
		GameObjType _gameObjType;
	}
	protected {
		objId		_id;
	}
}
