/**
 * This module provides a templated function that performs value-preserving
 * conversions between arbitrary types.  This function's behaviour can be
 * extended for user-defined types as needed.
 *
 * Patched to support conversion tests.
 *
 * Copyright:   Copyright &copy; 2007 Daniel Keep.
 * License:     BSD style: $(LICENSE)
 * Authors:     Daniel Keep, Eric Anderton
 * Credits:     Inspired in part by Andrei Alexandrescu's work on std.conv.
 */

module enkilib.d.Convert;

private import tango.core.Traits;
private import tango.core.Tuple : Tuple;

private import tango.math.Math;
private import tango.text.convert.Utf;
private import tango.text.convert.Float;
private import tango.text.convert.Integer;

private import Ascii = tango.text.Ascii;

version( DDoc )
{
    /**
     * Attempts to perform a value-preserving conversion of the given value
     * from type S to type D.  If the conversion cannot be performed in any
     * context, a compile-time error will be issued describing the types
     * involved.  If the conversion fails at run-time because the destination
     * type could not represent the value being converted, a
     * ConversionException will be thrown.
     *
     * For example, to convert the string "123" into an equivalent integer
     * value, you would use:
     *
     * -----
     * auto v = to!(int)("123");
     * -----
     *
     * You may also specify a default value which should be returned in the
     * event that the conversion cannot take place:
     *
     * -----
     * auto v = to!(int)("abc", 456);
     * -----
     *
     * The function will attempt to preserve the input value as exactly as
     * possible, given the limitations of the destination format.  For
     * instance, converting a floating-point value to an integer will cause it
     * to round the value to the nearest integer value.
     *
     * Below is a complete list of conversions between built-in types and
     * strings.  Capitalised names indicate classes of types.  Conversions
     * between types in the same class are also possible.
     *
     * -----
     * bool         <-- Integer (0/!0), Char ('t'/'f'), String ("true"/"false")
     * Integer      <-- bool, Real, Char ('0'-'9'), String
     * Real         <-- Integer, String
     * Imaginary    <-- Complex
     * Complex      <-- Integer, Real, Imaginary
     * Char         <-- bool, Integer (0-9)
     * String       <-- bool, Integer, Real
     * -----
     *
     * Conversions between arrays and associative arrays are also supported,
     * and are done element-by-element.
     *
     * You can add support for value conversions to your types by defining
     * appropriate static and instance member functions.  Given a type
     * the_type, any of the following members of a type T may be used:
     *
     * -----
     * the_type to_the_type();
     * static T from_the_type(the_type);
     * -----
     *
     * You may also use "camel case" names:
     *
     * -----
     * the_type toTheType();
     * static T fromTheType(the_type);
     * -----
     *
     * Arrays and associative arrays can also be explicitly supported:
     *
     * -----
     * the_type[] to_the_type_array();
     * the_type[] toTheTypeArray();
     *
     * static T from_the_type_array(the_type[]);
     * static T fromTheTypeArray(the_type[]);
     *
     * the_type[int] to_int_to_the_type_map();
     * the_type[int] toIntToTheTypeMap();
     *
     * static T from_int_to_the_type_map(the_type[int]);
     * static T fromIntToTheTypeMap(the_type[int]);
     * -----
     *
     * If you have more complex requirements, you can also use the generic to
     * and from templated members:
     *
     * -----
     * the_type to(the_type)();
     * static T from(the_type)(the_type);
     * -----
     *
     * These templates will have the_type explicitly passed to them in the
     * template instantiation.
     *
     * Finally, strings are given special support.  The following members will
     * be checked for:
     *
     * -----
     * char[]  toString();
     * wchar[] toString16();
     * dchar[] toString32();
     * char[]  toString();
     * -----
     *
     * The "toString_" method corresponding to the destination string type will be
     * tried first.  If this method does not exist, then the function will
     * look for another "toString_" method from which it will convert the result.
     * Failing this, it will try "toString" and convert the result to the
     * appropriate encoding.
     *
     * The rules for converting to a user-defined type are much the same,
     * except it makes use of the "fromUtf8", "fromUtf16", "fromUtf32" and
     * "fromString" static methods.
     */
    D to(D,S)(S value);
    D to(D,S)(S value, D default_); /// ditto
}
else
{
    template to(D)
    {
        D to(S, Def=Missing)(S value, Def def=Def.init)
        {
            alias toImpl!(D,S) impl;
            static if( is( typeof(impl.error) ) ){
                static assert(false,impl.error);
            }
            static if( is( Def == Missing ) ){
                return impl.op(value);
            }
            else
            {
                try
                {
                    return impl.op(value);
                }
                catch( ConversionException e ){
                    //do nothing
                }
                return def;
            }
        }
    }
    
    template canConvertTo(S,D)
    {
        static if( is( typeof(toImpl!(D,S).error) ) ){
            const bool canConvertTo = false;
        }
        else{
            const bool canConvertTo = true;
        }
    }
    
    template getConvertError(S,D)
    {
        static if( is( typeof(toImpl!(D,S).error) ) ){
            const char[] getConvertError = toImpl!(D,S).error;
        }
        else{
            const char[] getConvertError = "";
        }
    }    
}

/**
 * This exception is thrown when the to template is unable to perform a
 * conversion at run-time.  This typically occurs when the source value cannot
 * be represented in the destination type.  This exception is also thrown when
 * the conversion would cause an over- or underflow.
 */
class ConversionException : Exception
{
    this( char[] msg )
    {
        super( msg );
    }
}

private:

typedef int Missing;

/*
 * So, how is this module structured?
 *
 * Firstly, we need a bunch of support code.  The first block of this contains
 * some CTFE functions for string manipulation (to cut down on the number of
 * template symbols we generate.)
 *
 * The next contains a boat-load of templates.  Most of these are trait
 * templates (things like isPOD, isObject, etc.)  There are also a number of
 * mixins, and some switching templates (like toString_(n).)
 *
 * Another thing to mention is intCmp, which performs a safe comparison
 * between two integers of arbitrary size and signage.
 *
 * Following all this are the templated to* implementations.
 *
 * The actual toImpl template is the second last thing in the module, with the
 * module unit tests coming last.
 */

char ctfe_upper(char c)
{
    if( 'a' <= c && c <= 'z' )
        return (c - 'a') + 'A';
    else
        return c;
}

char[] ctfe_camelCase(char[] s)
{
    char[] result;

    bool nextIsCapital = true;

    foreach( c ; s )
    {
        if( nextIsCapital )
        {
            if( c == '_' )
                result ~= c;
            else
            {
                result ~= ctfe_upper(c);
                nextIsCapital = false;
            }
        }
        else
        {
            if( c == '_' )
                nextIsCapital = true;
            else
                result ~= c;
        }
    }

    return result;
}

bool ctfe_isSpace(T)(T c)
{
    static if (T.sizeof is 1)
        return (c <= 32 && (c is ' ' | c is '\t' | c is '\r'
                    | c is '\n' | c is '\v' | c is '\f'));
    else
        return (c <= 32 && (c is ' ' | c is '\t' | c is '\r'
                    | c is '\n' | c is '\v' | c is '\f'))
            || (c is '\u2028' | c is '\u2029');
}

T[] ctfe_triml(T)(T[] source)
{
    if( source.length == 0 )
        return null;

    foreach( i,c ; source )
        if( !ctfe_isSpace(c) )
            return source[i..$];

    return null;
}

T[] ctfe_trimr(T)(T[] source)
{
    if( source.length == 0 )
        return null;

    foreach_reverse( i,c ; source )
        if( !ctfe_isSpace(c) )
            return source[0..i+1];

    return null;
}

T[] ctfe_trim(T)(T[] source)
{
    return ctfe_trimr(ctfe_triml(source));
}

template isPOD(T)
{
    static if( is( T == struct ) || is( T == union ) )
        const isPOD = true;
    else
        const isPOD = false;
}

template isObject(T)
{
    static if( is( T == class ) || is( T == interface ) )
        const isObject = true;
    else
        const isObject = false;
}

template isUDT(T)
{
    const isUDT = isPOD!(T) || isObject!(T);
}

template isString(T)
{
    static if( is( typeof(T[]) == char[] )
            || is( typeof(T[]) == wchar[] )
            || is( typeof(T[]) == dchar[] ) )
        const isString = true;
    else
        const isString = false;
}

template isArrayType(T)
{
    const isArrayType = isDynamicArrayType!(T) || isStaticArrayType!(T);
}

template isPointerType(T)
{
    /*
     * You might think these first two tests are redundant.  You'd be wrong.
     * The linux compilers, for whatever reason, seem to think that objects
     * and arrays are implicitly castable to void*, whilst the Windows one
     * doesn't.  Don't ask me; just nod and smile...
     */
    static if( is( T : Object ) )
        const isPointerType = false;
    else static if( is( T : void[] ) )
        const isPointerType = false;
    else static if( is( T : void* ) )
        const isPointerType = true;
    else
        const isPointerType = false;
}

static assert( isPointerType!(char*) );
static assert( isPointerType!(void*) );
static assert( !isPointerType!(char[]) );
static assert( !isPointerType!(void[]) );
static assert( !isPointerType!(typeof("abc")) );
static assert( !isPointerType!(Object) );

/*
 * Determines which signed integer type of T and U is larger.
 */
template sintSuperType(T,U)
{
    static if( is( T == long ) || is( U == long ) )
        alias long sintSuperType;
    else static if( is( T == int ) || is( U == int ) )
        alias int sintSuperType;
    else static if( is( T == short ) || is( U == short ) )
        alias short sintSuperType;
    else static if( is( T == byte ) || is( U == byte ) )
        alias byte sintSuperType;
}

/*
 * Determines which unsigned integer type of T and U is larger.
 */
template uintSuperType(T,U)
{
    static if( is( T == ulong ) || is( U == ulong ) )
        alias ulong uintSuperType;
    else static if( is( T == uint ) || is( U == uint ) )
        alias uint uintSuperType;
    else static if( is( T == ushort ) || is( U == ushort ) )
        alias ushort uintSuperType;
    else static if( is( T == ubyte ) || is( U == ubyte ) )
        alias ubyte uintSuperType;
}

template uintOfSize(uint bytes)
{
    static if( bytes == 1 )
        alias ubyte uintOfSize;
    else static if( bytes == 2 )
        alias ushort uintOfSize;
    else static if( bytes == 4 )
        alias uint uintOfSize;
}

/*
 * Safely performs a comparison between two integer values, taking into
 * account different sizes and signages.
 */
int intCmp(T,U)(T lhs, U rhs)
{
    static if( isSignedIntegerType!(T) && isSignedIntegerType!(U) )
    {
        alias sintSuperType!(T,U) S;
        auto l = cast(S) lhs;
        auto r = cast(S) rhs;
        if( l < r ) return -1;
        else if( l > r ) return 1;
        else return 0;
    }
    else static if( isUnsignedIntegerType!(T) && isUnsignedIntegerType!(U) )
    {
        alias uintSuperType!(T,U) S;
        auto l = cast(S) lhs;
        auto r = cast(S) rhs;
        if( l < r ) return -1;
        else if( l > r ) return 1;
        else return 0;
    }
    else
    {
        static if( isSignedIntegerType!(T) )
        {
            if( lhs < 0 )
                return -1;
            else
            {
                static if( U.sizeof >= T.sizeof )
                {
                    auto l = cast(U) lhs;
                    if( l < rhs ) return -1;
                    else if( l > rhs ) return 1;
                    else return 0;
                }
                else
                {
                    auto l = cast(ulong) lhs;
                    auto r = cast(ulong) rhs;
                    if( l < r ) return -1;
                    else if( l > r ) return 1;
                    else return 0;
                }
            }
        }
        else static if( isSignedIntegerType!(U) )
        {
            if( rhs < 0 )
                return 1;
            else
            {
                static if( T.sizeof >= U.sizeof )
                {
                    auto r = cast(T) rhs;
                    if( lhs < r ) return -1;
                    else if( lhs > r ) return 1;
                    else return 0;
                }
                else
                {
                    auto l = cast(ulong) lhs;
                    auto r = cast(ulong) rhs;
                    if( l < r ) return -1;
                    else if( l > r ) return 1;
                    else return 0;
                }
            }
        }
    }
}

template unsupported(char[] desc="")
{
    const char[] error = "Unsupported conversion: cannot convert to "
            ~ctfe_trim(D.stringof)~" from "
            ~(desc!="" ? desc~" " : "")~ctfe_trim(S.stringof)~".";
}

template unsupported_backwards(char[] desc="")
{
    const char[] error = "Unsupported conversion: cannot convert to "
            ~(desc!="" ? desc~" " : "")~ctfe_trim(D.stringof)
            ~" from "~ctfe_trim(S.stringof)~".";
}

// TN works out the c_case name of the given type.
template TN(T:T[])
{
    static if( is( T == char ) )
        const TN = "string";
    else static if( is( T == wchar ) )
        const TN = "wstring";
    else static if( is( T == dchar ) )
        const TN = "dstring";
    else
        const TN = TN!(T)~"_array";
}

// ditto
template TN(T:T*)
{
    const TN = TN!(T)~"_pointer";
}

// ditto
template TN(T)
{
    static if( isAssocArrayType!(T) )
        const TN = TN!(typeof(T.keys[0]))~"_to_"
            ~TN!(typeof(T.values[0]))~"_map";
    else
        const TN = ctfe_trim(T.stringof);
}

// Picks an appropriate toUtf* method from t.text.convert.Utf.
template toString_(T)
{
    static if( is( T == char[] ) )
        alias tango.text.convert.Utf.toString toString_;

    else static if( is( T == wchar[] ) )
        alias tango.text.convert.Utf.toString16 toString_;

    else
        alias tango.text.convert.Utf.toString32 toString_;
}

template UtfNum(T)
{
    const UtfNum = is(typeof(T[0])==char) ? "8" : (
            is(typeof(T[0])==wchar) ? "16" : "32");
}

template StringNum(T)
{
    const StringNum = is(typeof(T[0])==char) ? "" : (
            is(typeof(T[0])==wchar) ? "16" : "32");
}

// This mixin defines a general function for converting to a UDT.
template toUDT()
{
    static if( isString!(S) )
    {
        static if( is( typeof(mixin("D.fromUtf"~UtfNum!(S)~"(S.init)")) : D ) )
            mixin("alias D.fromUtf"~UtfNum!(S)~" op;");

        else static if( is( typeof(D.fromUtf8(""c)) : D ) )
            D op(S value){ return D.fromUtf8(toString_!(char[])(value)); }

        else static if( is( typeof(D.fromUtf16(""w)) : D ) )
            D op(S value){ return D.fromUtf16(toString_!(wchar[])(value)); }

        else static if( is( typeof(D.fromUtf32(""d)) : D ) )
            D op(S value){ return D.fromUtf32(toString_!(dchar[])(value)); }

        else static if( is( typeof(D.fromString(""c)) : D ) )
        {
            static if( is( S == char[] ) )
                alias D.fromString op;
            else
               D op(S value){ return D.fromString(toString_!(char[])(value)); }
        }

        // Default fallbacks
        else static if( is( typeof(D.from!(S)(S.init)) : D ) )
             alias D.from!(S) op;
        else
            mixin unsupported!("user-defined type");
    }
    else
    {
        // TODO: Check for templates.  Dunno what to do about them.

        static if( is( typeof(mixin("D.from_"~TN!(S)~"(S.init)")) : D ) )
            mixin("alias D.from_"~TN!(S)~" op;");
        else static if( is( typeof(mixin("D.from"
                            ~ctfe_camelCase(TN!(S))~"(S.init)")) : D ) )
            mixin("alis D.from"~ctfe_camelCase(TN!(S))~" op;");
        else static if( is( typeof(D.from!(S)(S.init)) : D ) )
             alias D.from!(S) op;
        else
            mixin unsupported!("user-defined type");
    }
}

// This mixin defines a general function for converting from a UDT.
template fromUDT(S,char[] fallthrough="")
{
    static if( isString!(D) )
    {
        static if( is( typeof(mixin("S.init.toString"
                            ~StringNum!(D)~"()")) == D ) )
             D op(S value){ return mixin("value.toString"~StringNum!(D)~"()"); }
             
        else static if( is( typeof(S.init.toString()) == char[] ) )
             D op(S value){ return toString_!(D)(value.toString); }

        else static if( is( typeof(S.init.toString16()) == wchar[] ) )
             D op(S value){ return toString_!(D)(value.toString16); }

        else static if( is( typeof(S.init.toString32()) == dchar[] ) )
             D op(S value){ return toString_!(D)(value.toString32); }

        else static if( is( typeof(S.init.toString()) == char[] ) )
        {
            static if( is( D == char[] ) )
                 alias value.toString op;

            else
            {
                 D op(S value){ return toString_!(D)(value.toString); }
            }
        }

        // Default fallbacks

        else static if( is( typeof(S.init.to!(D)()) : D ) )
            D op(S value){ return value.to!(D)(); }
        else static if( fallthrough != "" )
            mixin(fallthrough);
        else
            mixin unsupported!("user-defined type");
    }
    else
    {
        // TODO: Check for templates.  Dunno what to do about them.
        static if( is( typeof(mixin("S.init.to_"~TN!(D)~"()")) : D ) )
            D op(S value){ return mixin("value.to_"~TN!(D)~"()"); }
        else static if( is( typeof(mixin("S.init.to"~ctfe_camelCase(TN!(D))~"()")) : D ) )
            D op(S value){ return mixin("value.to"~ctfe_camelCase(TN!(D))~"()"); }
        else static if( is( typeof(S.init.to!(D)()) : D ) )
            D op(S value){ return value.to!(D)(); }
        else static if( fallthrough != "" )
            mixin(fallthrough);
        else
            mixin unsupported!("user-defined type");
    }
}

template convError()
{
    void throwConvError()
    {
        // Since we're going to use to!(T) to convert the value to a string,
        // we need to make sure we don't end up in a loop...
        static if( isString!(D) || !is( typeof(to!(char[])(value)) == char[] ) )
        {
            throw new ConversionException("Could not convert a value of type "
                    ~S.stringof~" to type "~D.stringof~".");
        }
        else
        {
            throw new ConversionException("Could not convert `"
                    ~to!(char[])(value)~"` of type "
                    ~S.stringof~" to type "~D.stringof~".");
        }
    }
}

template toBool(D,S){
    static assert(is(D==bool));

    static if( isIntegerType!(S) /+|| isRealType!(S) || isImaginaryType!(S)
                || isComplexType!(S)+/ )
        // The weird comparison is to support NaN as true
        D op(S value){ return !(value == 0); }

    else static if( isCharType!(S) )
    {
        D op(S value){ 
            switch( value )
            {
                case 'F': case 'f':
                    return false;

                case 'T': case 't':
                    return true;

                default:
                    mixin convError;
                    throwConvError;
            }
        }
    }

    else static if( isString!(S) )
    {
        D op(S value){ 
            switch( Ascii.toLower(value) )
            {
                case "false":
                    return false;

                case "true":
                    return true;

                default:
                    mixin convError;
                    throwConvError;
            }
        }
    }
    /+
    else static if( isDynamicArrayType!(S) || isStaticArrayType!(S) )
    {
        mixin unsupported!("array type");
    }
    else static if( isAssocArrayType!(S) )
    {
        mixin unsupported!("associative array type");
    }
    else static if( isPointerType!(S) )
    {
        mixin unsupported!("pointer type");
    }
    else static if( is( S == typedef ) )
    {
        mixin unsupported!("typedef'ed type");
    }
    // +/
    else static if( isPOD!(S) || isObject!(S) )
    {
        mixin fromUDT!(S);
    }
    else
    {
        mixin unsupported;
    }
}

template toIntegerFromInteger(D,S){
    static if( (cast(ulong) D.max) >= (cast(ulong) S.max)
            && (cast(long) D.min) <= (cast(long) S.min) )
    {
        D op(S value){ return cast(D) value; }
    }
    else
    {
        D op(S value){ 
            mixin convError; // TODO: Overflow error

            if( intCmp(value,D.min)<0 || intCmp(value,D.max)>0 )
            {
                throwConvError;
            }
            else
                return cast(D) value;
        }
    }
}

template toIntegerFromReal(D,S){
    D op(S value){ 
        auto v = tango.math.Math.round(value);
        if( (cast(real) D.min) <= v && v <= (cast(real) D.max) )
        {
            return cast(D) v;
        }
        else
        { 
            mixin convError; // TODO: Overflow error
            throwConvError;
        }
    }
}

template toIntegerFromString(D,S){
    static if( is( S charT : charT[] ) )
    {
        D op(S value){ 
            mixin convError;

            static if( is( D == ulong ) )
            {
                uint len;
                auto result = tango.text.convert.Integer.convert(value, 10, &len);

                if( len < value.length )
                    throwConvError;

                return result;
            }
            else
            {
                uint len;
                auto result = tango.text.convert.Integer.parse(value, 10, &len);

                if( len < value.length )
                    throwConvError;

                return toIntegerFromInteger!(D,long)(result);
            }
        }
    }
    else
    {
        mixin unsupported;
    }
}

template toInteger(D,S){
    static if( is( S == bool ) )
        D op(S value){ return (value ? 1 : 0); }

    else static if( isIntegerType!(S) )
    {
        D op(S value){ return toIntegerFromInteger!(D,S)(value); }
    }
    else static if( isCharType!(S) )
    {
        D op(S value){ 
            if( value >= '0' && value <= '9' )
            {
                return cast(D)(value - '0');
            }
            else
            {
                mixin convError;
                throwConvError;
            }
        }
    }
    else static if( isRealType!(S) )
    {
        D op(S value){ return toIntegerFromReal!(D,S)(value); }
    }
    else static if( isString!(S) )
    {
        D op(S value){ return toIntegerFromString!(D,S)(value); }
    }
    else static if( isPOD!(S) || isObject!(S) )
    {
        mixin fromUDT!(S);
    }
    else
        mixin unsupported;
}

template toReal(D,S){
    /+static if( is( S == bool ) )
         D op(S value){ return (value ? 1.0 : 0.0); }

    else+/ static if( isIntegerType!(S) || isRealType!(S) )
         D op(S value){ return cast(D) value; }

    /+else static if( isCharType!(S) )
         D op(S value){ return cast(D) to!(uint)(value); }+/

    else static if( isString!(S) )
         D op(S value){ return tango.text.convert.Float.parse(value); }

    else static if( isPOD!(S) || isObject!(S) )
        mixin fromUDT!(S);
    else
        mixin unsupported;
}

template toImaginary(D,S){
    /+static if( is( S == bool ) )
         D op(S value){ return (value ? 1.0i : 0.0i); }

    else+/ static if( isComplexType!(S) )
    {
        D op(S value){ 
            if( value.re == 0.0 )
                return value.im * cast(D)1.0i;

            else
            {
                mixin convError;
                throwConvError;
            }
        }
    }
    else static if( isPOD!(S) || isObject!(S) )
        mixin fromUDT!(S);
    else
        mixin unsupported;
}

template toComplex(D,S){
    static if( isIntegerType!(S) || isRealType!(S) || isImaginaryType!(S)
            || isComplexType!(S) )
         D op(S value){ return cast(D) value; }

    /+else static if( isCharType!(S) )
         D op(S value){  return cast(D) to!(uint)(value); }+/

    else static if( isPOD!(S) || isObject!(S) )
        mixin fromUDT!(S);
    else
        mixin unsupported;
}

template toChar(D,S){
    static if( is( S == bool ) )
         D op(S value){ return (value ? 't' : 'f'); }

    else static if( isIntegerType!(S) )
    {
        D op(S value){ 
            if( value >= 0 && value <= 9 )
                return cast(D) value+'0';

            else
            {
                mixin convError; // TODO: Overflow error
                throwConvError;
            }
        }
    }
    else static if( isPOD!(S) || isObject!(S) )
        mixin fromUDT!(S);
    else
        mixin unsupported;
}

template toStringFromString(D,S){
    static if( is( typeof(D[0]) == char ) )
         D op(S value){ return tango.text.convert.Utf.toString(value); }

    else static if( is( typeof(D[0]) == wchar ) )
         D op(S value){ return tango.text.convert.Utf.toString16(value); }

    else static if( is( typeof(D[0]) == dchar ) )
        D op(S value){ return tango.text.convert.Utf.toString32(value); }
    else
        mixin unsupported;
}

template toString(D,S){
    static if( is( S == bool ) )
        D op(S value){ return (value ? "true" : "false"); }

    else static if( isIntegerType!(S) )
        // TODO: Make sure this works with ulongs.
        mixin("alias tango.text.convert.Integer.toString"~StringNum!(D)~" op;");

    else static if( isRealType!(S) )
        mixin("alias tango.text.convert.Float.toString"~StringNum!(D)~" op;");

    else static if( isDynamicArrayType!(S) || isStaticArrayType!(S) )
        mixin unsupported!("array type");

    else static if( isAssocArrayType!(S) )
        mixin unsupported!("associative array type");

    else static if( isPOD!(S) || isObject!(S) )
        mixin fromUDT!(S);
    else
        mixin unsupported;
}

template fromString(D,S){
    static if( isDynamicArrayType!(S) || isStaticArrayType!(S) )
        mixin unsupported_backwards!("array type");

    else static if( isAssocArrayType!(S) )
        mixin unsupported_backwards!("associative array type");

    else static if( isPOD!(S) || isObject!(S) )
        mixin toUDT;
    else
        mixin unsupported_backwards;
}

template toArrayFromArray(D,S){
    alias typeof(D[0]) De;
    static if(!canConvertTo!(S,De)){
        const char[] error = toImpl!(De,S).error;
    }
    else{
        D op(S value){ 
            D result; result.length = value.length;
            scope(failure) delete result;

            foreach( i,e ; value )
                result[i] = to!(De)(e);

            return result;
        }
    }
}

template toMapFromMap(D,S){
    alias typeof(D.keys[0])   Dk;
    alias typeof(D.values[0]) Dv;
    alias typeof(S.keys[0])   Sk;
    alias typeof(S.values[0]) Sv;
    
    static if(!canConvertTo!(Sk,Dk)){
        const char[] error = toImpl!(Sk,Dk).error;
    }
    else static if(!canConvertTo!(Sv,Dv)){
        const char[] error = toImpl!(Sv,Dv).error;
    }
    else{
        D op(S value){ 
            D result;

            foreach( k,v ; value )
                result[ to!(Dk)(k) ] = to!(Dv)(v);

            return result;
        }
    }
}

template toFromUDT(D,S){
    // Try value.to* first
    static if( is( typeof(mixin("S.init.to_"~TN!(D)~"()")) : D ) )
        D op(S value){ return mixin("value.to_"~TN!(D)~"()"); }

    else static if( is( typeof(mixin("S.init.to"
                        ~ctfe_camelCase(TN!(D))~"()")) : D ) )
        D op(S value){ return mixin("value.to"~ctfe_camelCase(TN!(D))~"()"); }

    else static if( is( typeof(value.to!(D)()) : D ) )
        D op(S value){ return value.to!(D)(); }

    // Ok, try D.from* now
    else static if( is( typeof(mixin("D.from_"~TN!(S)~"(S.init)")) : D ) )
        mixin("alias D.from_"~TN!(S)~" op;");

    else static if( is( typeof(mixin("D.from"
                        ~ctfe_camelCase(TN!(S))~"(S.init)")) : D ) )
        mixin("D.from"~ctfe_camelCase(TN!(S))~" op;");

    else static if( is( typeof(D.from!(S)(S.init)) : D ) )
        alias D.from!(S) op;
        
    // try a plain old cast
    else static if( is(S : D) )
        D op(S value){ return cast(D)value; }        

    // Give up
    else
        mixin unsupported;
}

template toImpl(D,S){
    static if( is( D == S ) )
        D op(S value){ return value; }
    else static if( isArrayType!(D) && isArrayType!(S)
            && is( typeof(D[0]) == typeof(S[0]) ) )
        // Special-case which catches to!(T[])!(T[n]).
        D op(S value){ return value; }

    else{
        static if( is( D == bool ) )
            mixin toBool!(D,S);

        else static if( isIntegerType!(D) )
            mixin toInteger!(D,S);

        else static if( isRealType!(D) )
            mixin toReal!(D,S);

        else static if( isImaginaryType!(D) )
            mixin toImaginary!(D,S);

        else static if( isComplexType!(D) )
            mixin toComplex!(D,S);

        else static if( isCharType!(D) )
            mixin toChar!(D,S);

        else static if( isString!(D) && isString!(S) )
            mixin toStringFromString!(D,S);

        else static if( isString!(D) )
            mixin toString!(D,S);

        else static if( isString!(S) )
            mixin fromString!(D,S);

        else static if( isArrayType!(D) && isArrayType!(S) )
            mixin toArrayFromArray!(D,S);

        else static if( isAssocArrayType!(D) && isAssocArrayType!(S) )
            mixin toMapFromMap!(D,S);

        else static if( isUDT!(D) || isUDT!(S) )
            mixin toFromUDT!(D,S);
        
        else
            mixin unsupported;
    }
}
debug ( ConvertTest ):
    void main() {}

debug( UnitTest ):


bool ex(T)(lazy T v)
{
    bool result = false;
    try
    {
        v();
    }
    catch( Exception _ )
    {
        result = true;
    }
    return result;
}

bool nx(T)(lazy T v)
{
    bool result = true;
    try
    {
        v();
    }
    catch( Exception _ )
    {
        result = false;
    }
    return result;
}

struct Foo
{
    int toInt() { return 42; }

    char[] toString() { return "string foo"; }

    int[] toIntArray() { return [1,2,3]; }

    Bar toBar()
    {
        Bar result; return result;
    }

    T to(T)()
    {
        static if( is( T == bool ) )
            return true;
        else
            static assert( false );
    }
}

struct Bar
{
    real toReal()
    {
        return 3.14159;
    }

    ireal toIreal()
    {
        return 42.0i;
    }
}

struct Baz
{
    static Baz fromFoo(Foo foo)
    {
        Baz result; return result;
    }

    Bar toBar()
    {
        Bar result; return result;
    }
}

unittest
{
    /*
     * bool
     */
    static assert( !is( typeof(to!(bool)(1.0)) ) );
    static assert( !is( typeof(to!(bool)(1.0i)) ) );
    static assert( !is( typeof(to!(bool)(1.0+1.0i)) ) );

    assert( to!(bool)(0) == false );
    assert( to!(bool)(1) == true );
    assert( to!(bool)(-1) == true );

    assert( to!(bool)('t') == true );
    assert( to!(bool)('T') == true );
    assert( to!(bool)('f') == false );
    assert( to!(bool)('F') == false );
    assert(ex( to!(bool)('x') ));

    assert( to!(bool)("true") == true );
    assert( to!(bool)("false") == false );
    assert( to!(bool)("TrUe") == true );
    assert( to!(bool)("fAlSe") == false );

    /*
     * Integer
     */
    assert( to!(int)(42L) == 42 );
    assert( to!(byte)(42) == cast(byte)42 );
    assert( to!(short)(-1701) == cast(short)-1701 );
    assert( to!(long)(cast(ubyte)72) == 72L );

    assert(nx( to!(byte)(127) ));
    assert(ex( to!(byte)(128) ));
    assert(nx( to!(byte)(-128) ));
    assert(ex( to!(byte)(-129) ));

    assert(nx( to!(ubyte)(255) ));
    assert(ex( to!(ubyte)(256) ));
    assert(nx( to!(ubyte)(0) ));
    assert(ex( to!(ubyte)(-1) ));

    assert(nx( to!(long)(9_223_372_036_854_775_807UL) ));
    assert(ex( to!(long)(9_223_372_036_854_775_808UL) ));
    assert(nx( to!(ulong)(0L) ));
    assert(ex( to!(ulong)(-1L) ));

    assert( to!(int)(3.14159) == 3 );
    assert( to!(int)(2.71828) == 3 );

    assert( to!(int)("1234") == 1234 );

    assert( to!(int)(true) == 1 );
    assert( to!(int)(false) == 0 );

    assert( to!(int)('0') == 0 );
    assert( to!(int)('9') == 9 );

    /*
     * Real
     */
    assert( to!(real)(3) == 3.0 );
    assert( to!(real)("1.125") == 1.125 );

    /*
     * Imaginary
     */
    static assert( !is( typeof(to!(ireal)(3.0)) ) );

    assert( to!(ireal)(0.0+1.0i) == 1.0i );
    assert(nx( to!(ireal)(0.0+1.0i) ));
    assert(ex( to!(ireal)(1.0+0.0i) ));

    /*
     * Complex
     */
    assert( to!(creal)(1) == (1.0+0.0i) );
    assert( to!(creal)(2.0) == (2.0+0.0i) );
    assert( to!(creal)(3.0i) == (0.0+3.0i) );

    /*
     * Char
     */
    assert( to!(char)(true) == 't' );
    assert( to!(char)(false) == 'f' );

    assert( to!(char)(0) == '0' );
    assert( to!(char)(9) == '9' );

    assert(ex( to!(char)(-1) ));
    assert(ex( to!(char)(10) ));

    /*
     * String-string
     */
    assert( to!(char[])("I love to eat"w) == "I love to eat"c );
    assert( to!(char[])("them smurfies"d) == "them smurfies"c );
    assert( to!(wchar[])("Smurfies what I love"c) == "Smurfies what I love"w );
    assert( to!(dchar[])("bite they ugly"c) == "bite they ugly"d );
    assert( to!(dchar[])("heas off"w) == "heads off"d );
    // ... nibble on they bluish feet.

    /*
     * String
     */
    assert( to!(char[])(true) == "true" );
    assert( to!(char[])(false) == "false" );

    assert( to!(char[])(12345678) == "12345678" );
    assert( to!(char[])(1234.567800) == "1234.57");

    /*
     * Array-array
     */
    assert( to!(ubyte[])([1,2,3]) == [cast(ubyte)1, 2, 3] );
    assert( to!(bool[])(["true"[], "false"]) == [true, false] );

    /*
     * Map-map
     */
    {
        char[][int] src = [1:"true"[], 2:"false"];
        bool[ubyte] dst = to!(bool[ubyte])(src);
        assert( dst.keys.length == 2 );
        assert( dst[1] == true );
        assert( dst[2] == false );
    }

    /*
     * UDT
     */
    {
        Foo foo;

        assert( to!(bool)(foo) == true );
        assert( to!(int)(foo) == 42 );
        assert( to!(char[])(foo) == "string foo" );
        assert( to!(wchar[])(foo) == "string foo"w );
        assert( to!(dchar[])(foo) == "string foo"d );
        assert( to!(int[])(foo) == [1,2,3] );
        assert( to!(ireal)(to!(Bar)(foo)) == 42.0i );
        assert( to!(real)(to!(Bar)(to!(Baz)(foo))) == 3.14159 );
    }

    /*
     * Default values
     */
    {
        assert( to!(int)("123", 456) == 123,
                `to!(int)("123", 456) == "` ~ to!(char[])(
                    to!(int)("123", 456)) ~ `"` );
        assert( to!(int)("abc", 456) == 456,
                `to!(int)("abc", 456) == "` ~ to!(char[])(
                    to!(int)("abc", 456)) ~ `"` );
    }
}
