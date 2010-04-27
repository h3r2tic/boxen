module xf.utils.Union;



pragma (ctfe) char[] makeTypedUnion(char[] name, char[][] origTypes, char[][] typeNames) {
	char[] result = "struct " ~ name ~ " {"\n;

	result ~= \t"enum Type : ubyte {"\n;
	foreach (n; typeNames) {
		result ~= \t\t ~ n ~ ","\n;
	}
	result ~= \t"}"\n\n;
	
	result ~= \t"union {"\n;
	foreach (i, n; typeNames) {
		result ~= \t\t ~ origTypes[i] ~ "\t" ~ n ~ ";"\n;
	}
	result ~= \t"}"\n\n;
	result ~= \t"Type type;"\n\n;

	result ~= \t"template TypeT(T) {"\n;
	foreach (i, n; typeNames) {
		result ~= \t\t;
		if (i > 0) result ~= "else ";
		
		result ~= "static if (is(T == " ~ origTypes[i] ~ ")) const Type TypeT = Type." ~ n ~ ";"\t;
	}
	result ~= \t\t"else static assert (false, `No union member for type ` ~ T.stringof);"\n;
	result ~= \t"}"\n\n;
	
	result ~= \t"static " ~ name ~ " opCall(Type type) {"\n;
	result ~= \t ~ name ~ " res; res.type = type; return res;";
	result ~= \t"}"\n\n;
	
	foreach (i, n; typeNames) {
		result ~= \t"static " ~ name ~ " opCall(" ~ origTypes[i] ~ " v) {"\n;
		result ~= \t\t ~ name ~ " result = void;"\n;
		result ~= \t\t"result.type = Type." ~ n ~ ";"\n;
		result ~= \t\t"result." ~ n ~ " = v;"\n;
		result ~= \t\t"return result;"\n;
		result ~= \t"}"\n\n;
	}

	result ~= "}"\n;
	
	return result;
}
