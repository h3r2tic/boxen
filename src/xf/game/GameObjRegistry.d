module xf.game.GameObjRegistry;

private {
	import xf.game.GameObj;
	import xf.game.Defs : playerId, objId;
	import xf.game.Log : log = gameLog;
	import xf.omg.core.LinearAlgebra;
}



void register(T)() {
	auto type = _nextType++;
	T.overrideGameObjType(type);
	_typeFactories ~=
		function GameObj(vec3 offset, objId id, playerId owner) {
			log.trace("Creating a {}", T.stringof);
			return new T(offset, id, owner);
		};
	_typeToName ~= T.stringof;
	_nameToType[T.stringof] = type;
}


void reassignType(char[] typeName, GameObjType type) {
	if (!(typeName in _nameToType) || type >= _typeToName.length) {
		throw new Exception("Type not registered: '" ~ typeName ~ "' unable to re-assign");
	}

	auto prev = _nameToType[typeName];
	
	if (prev != type) {
		{
			auto t = _typeFactories[type];
			_typeFactories[type] = _typeFactories[prev];
			_typeFactories[prev] = t;
		}
		{
			auto t = _typeToName[type];
			_typeToName[type] = typeName;
			_typeToName[prev] = t;
		}
	}
}


GameObj create(char[] typeName, vec3 offset, objId id, playerId owner) {
	log.trace("Attempting to create an object of type \"{}\"", typeName);
	return create(_nameToType[typeName], offset, id, owner);
}


GameObj create(GameObjType type, vec3 offset, objId id, playerId owner) {
	log.trace("Attempting to create an object of type={}", cast(int)type);
	return _typeFactories[type](offset, id, owner);
}


GameObjType getGameObjType(char[] name) {
	return _nameToType[name];
}


private {
	GameObjType[char[]]	_nameToType;
	char[][]			_typeToName;
	GameObjType			_nextType = 0;

	GameObj function(vec3, objId, playerId)[] _typeFactories;
}

