module xf.boxen.GameObjRegistry;

private {
	import xf.game.GameObj;
	import xf.game.Misc : playerId;
	import xf.omg.core.LinearAlgebra;
	import xf.utils.Singleton;

	// tmp
	import tango.stdc.stdio : printf;
}



class GameObjRegistry {
	void register(T)() {
		auto type = _nextType++;
		T.overrideType(type);
		_typeFactories ~=
			function IGameObj(vec3 offset, playerId owner) {
				printf("Creating a %.*s\n", T.stringof);
				return new T(offset, owner);
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
	
	
	GameObj create(char[] typeName, vec3 offset, playerId owner) {
		printf("Attempting to create an object of type \"%.*s\"\n", typeName);
		return create(_nameToType[typeName], offset, owner);
	}
	
	
	GameObj create(GameObjType type, vec3 offset, playerId owner) {
		printf("Attempting to create an object of type=%d\n", cast(int)type);
		return _typeFactories[type](offset, owner);
	}
	
	
	GameObjType[char[]]	_nameToType;
	char[][]			_typeToName;
	GameObjType			_nextType = 0;
	
	GameObj function(vec3, playerId)[] _typeFactories;
}


alias Singleton!(GameObjRegistry) gameObjRegistry;
