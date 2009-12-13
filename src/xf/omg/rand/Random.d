module xf.omg.rand.Random;
import tango.time.Clock;
import tango.math.Math;
import tango.core.Traits;

template Shared(T){
	static T shared;
	
	static this(){
		shared = new T;
	}
	
	static uint opCall(){
		return shared.getUint();
	}
	
	alias getUint opCall;
}

/**
	to create your generator write
	
	class Foo : Random!(Foo){
		
	}
*/
abstract class Random (T) : RandomGenerator {
	mixin Shared!(T);
}

abstract class RandomGenerator{
	
	this () {
		seed();
	}
	
	this (uint s) {
		seed(s);
	}
	
	final T getRandomElement(T)(T[] array){
		return T[getUint%$];
	}
	
	abstract uint _getUint();  
	
	final uint getUint(char[0] str="")(){
		return _getUint();
	}
	
	final uint getUint(char[1] str="]")(uint max){
		static if ( str == "]" ) {
			return getUint() % (max+1); 
		} else static if ( str == ")" ) {
			return getUint() % max;
		} else static assert ( false, `template attribute must be "]" or ")"`);
	}
	
	
	final uint getUint(char[2] str="[]")(uint min, uint max){
		static if (str == "[]") {
			return (getUint() % ( max - min + 1)) + min;
		} else static if (str == "()") {
			return (getUint() % ( max - min - 1)) + min + 1;
		} else static if (str == "[)") {
			return (getUint() % ( max - min)) + min;
		} else static if (str == "(]") {
			return (getUint() % ( max - min)) + min+1;
		} else static assert(false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	
	final ulong getUlong(char[0] str="")(){
		return  ((cast(ulong)(getUint())) << uint.sizeof*8) | getUint();
	}	
	
	final ulong getUlong(char[1] str="]")(ulong max){
		static if ( str == "]" ) {
			return getUlong() % (max+1); 
		} else static if ( str == ")" ) {
			return getUlong() % max;
		} else static assert ( false, `template attribute must be "]" or ")"`);
	}
	
	final ulong getUlong(char[2] str="[]")(ulong min, ulong max){
		static if (str == "[]") {
			return (getUlong() % ( max - min + 1)) + min;
		} else static if (str == "()") {
			return (getUlong() % ( max - min - 1)) + min + 1;
		} else static if (str == "[)") {
			return (getUlong() % ( max - min)) + min;
		} else static if (str == "(]") {
			return (getUlong() % ( max - min)) + min+1;
		} else static assert(false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	final ushort getUshort(char[0] str="")(){
		return cast(ushort) getUint();
	}
	
	final ushort getUshort(char[1] str="]")(ushort max){
		return cast(ushort) getUint!(str)(max);
	}
	
	final ushort getUshort(char[2] str="[]")(ushort min, ushort max) {
		return cast(ushort) getUint!(str)(min, max);
	}
	
	final ubyte getUbyte(char[0] str="")(){
		return cast(ubyte) getUint();
	}
	
	final ubyte getUbyte(char[1] str="]")(ubyte max){
		return cast(ubyte) getUint!(str)(max);
	}
	
	final ubyte getUbyte(char[2] str="[]")(ubyte min, ubyte max) {
		return cast(ubyte) getUint!(str)(min, max);
	}
	
	final int getInt(char[0] str = "") () {
		return cast(int) getUint() ;
	}
	
	final int getInt(char[1] str = "]") (int max) {
		static if ( str == "]" ) {
			return getInt!("(]")( int.min, max);
		} else static if ( str == ")" ) {
			return getInt!("()")( int.min, max);
		} else static assert ( false, `template attribute must be "]" or ")"`);
	}
	
	final int getInt(char[2] str = "[]") (int min, int max) {					
		static if (str == "[]") {
			return getUint!("]")( abs(max-min) ) + min; 
		} else static if (str == "()") {
			return getUint!(")")( abs(max-min) - 2) + min+1;
		} else static if (str == "[)") {
			return getUint!(")")( abs(max-min) -1 ) + min; 
		} else static if (str == "(]") {
			return getUint!("]")( abs(max-min) -1 ) + min+1;
		} else static assert(false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	final long getLong(char[0] str = "") () {
		return cast(long) getUlong() ;
	}
	
	final long getLong(char[1] str = "]") (int max) {
		static if ( str == "]" ) {
			return getLong!("(]")( long.min, max);
		} else static if ( str == ")" ) {
			return getLong!("()")( long.min, max);
		} else static assert ( false, `template attribute must be "]" or ")"`);
	}
	
	final long getLong(char[2] str = "[]") (long min, long max) {					
		static if (str == "[]") {
			return getUlong!("]")( abs(max-min) ) + min; 
		} else static if (str == "()") {
			return getUlong!(")")( abs(max-min) - 2) + min+1;
		} else static if (str == "[)") {
			return getUlong!(")")( abs(max-min) -1 ) + min; 
		} else static if (str == "(]") {
			return getUlong!("]")( abs(max-min) -1 ) + min+1;
		} else static assert(false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	final short getShort(char[0] str="")(){
		return cast(short) getInt();
	}
	
	final short getShort(char[1] str="]")(short max){
		return cast(short) getInt!(str)(max);
	}
	
	final short getShort(char[2] str="[]")(short min, short max) {
		return cast(short) getInt!(str)(min, max);
	}
	
	final byte getByte(char[0] str="")(){
		return cast(byte) getInt();
	}
	
	final byte getByte(char[1] str="]")(byte max){
		return cast(byte) getInt!(str)(max);
	}
	
	final byte getByte(char[2] str="[]")(byte min, byte max) {
		return cast(byte) getInt!(str)(min, max);
	}
	
	final uint getUint31(char[0] str="")() {
		return getUint()>>1;
	}
	
	final uint getUint31(char[1] str="]")(uint max) {
		static if ( str == "]" ) {
			return getUint31() % (max+1); 
		} else static if ( str == ")" ) {
			return getUint31() % max;
		} else static assert ( false, `template attribute must be "]" or ")"`);
	}
	
	final uint getUint31(char[2] str="[]")(uint min, uint max) {
		static if (str == "[]") {
			return (getUint31() % ( max - min + 1)) + min;
		} else static if (str == "()") {
			return (getUint31() % ( max - min - 1)) + min + 1;
		} else static if (str == "[)") {
			return (getUint31() % ( max - min)) + min;
		} else static if (str == "(]") {
			return (getUint31() % ( max - min)) + min+1;
		} else static assert(false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	final float getFloat(char[2] str = "[]")(){
		static if (str == "[]") {
			return getUint()*(1.0/cast(float)uint.max);
		} else static if (str == "()") {
			return ((cast(float)getUint()) + 0.5)*(1.0/(cast(float)uint.max+1.0));
		} else static if (str == "[)") {
			return getUint()*(1.0/(cast(double)uint.max+1.0));
		} else static if (stri == "(]") {
			return ((cast(float)getUint()) + 0.5)*(1.0/(cast(float)uint.max));
		} else static assert (false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	final double getDouble(char[2] str = "[]")(){
		static if (str == "[]") {
			return getUlong()*(1.0/cast(double)ulong.max);
		} else static if (str == "()") {
			return ((cast(double)getUlong()) + 0.5)*(1.0/(cast(double)ulong.max+1.0));
		} else static if (str == "[)") {
			return getUlong()*(1.0/(cast(double)ulong.max+1.0));
		} else static if (stri == "(]") {
			return ((cast(double)getUlong()) + 0.5)*(1.0/(cast(double)ulong.max));
		} else static assert (false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	final real getReal(char[2] str = "[]")(){
		static if (str == "[]") {
			return getUlong()*(1.0/cast(real)long.max);
		} else static if (str == "()") {
			return ((cast(real)getUlong()) + 0.5)*(1.0/(cast(real)ulong.max+1.0));
		} else static if (str == "[)") {
			return getUlong()*(1.0/(cast(real)ulong.max+1.0));
		} else static if (stri == "(]") {
			return ((cast(real)getUint()) + 0.5)*(1.0/(cast(real)ulong.max));
		} else static assert (false , `template attribute must be one of "[]" , "()", "[)" or "(]"`);
	}
	
	template get_(T,char[] str) {	
		static if ( isRealType!(T) ){
			final T get () {			
				mixin(
					"return get"~cast(char)(T.stringof[0]+('A'-'a'))~T.stringof[1..$]~`!("`~str~`")();`
				);
			}
		} else static if ( isIntegerType!(T) ) {
			final T get () {			
				mixin(
					"return get"~cast(char)(T.stringof[0]+('A'-'a'))~T.stringof[1..$]~`();`
				);
			}
			
			final T get (T max) {
				mixin(
					"return get"~cast(char)(T.stringof[0]+('A'-'a'))~T.stringof[1..$]~`!("`~str[(str.length==2?1:0)..$]~`")(max);`
				);
			}
			
			final T get (T min, T max) {
				mixin(
					"return get"~cast(char)(T.stringof[0]+('A'-'a'))~T.stringof[1..$]~`!("`~str~`")(min, max);`
				);
			}
		} else static assert(false , "not supported " ~ T.stringof);
		
	}
	
	template get(T, char[] str="[]"){
		alias get_!(T,str).get get;
	}
	
	/+
	// possibilities complex, fixed point ?? +/
	
	
	abstract RandomGenerator seed(uint s);
	
	
	final RandomGenerator seed(){
		return seed(Clock.now.span.millis);
	} 
}