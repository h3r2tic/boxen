module xf.game.Defs;



enum { maxPlayers = 32 }

typedef uint	tick;
typedef ushort	objId;
typedef ubyte	playerId;


enum : playerId {
	NoAuthority		= playerId.max-1,
	NoPlayer		= NoAuthority,
	ServerAuthority	= playerId.max
}


enum StateOverrideMethod {
	Replace,
	ApplyDiff
}
