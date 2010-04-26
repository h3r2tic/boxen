/**
Defines handy functions for managing class/widget properties which may be accessed as normal D
properties or through text-based lookups and template + rtti calls

Example:
---
import tango.util.log.Trace;

class Base : IPropertySupport {
	mixin MPropertySupport;
}


class Derived : Base {
	mixin(defineProperties("out bool clicked, inline char[] text"));
}


class Other : Base {
	mixin(defineProperties("char[] text"));
}


void foo() {
	auto der = new Derived;
	foreach (prop; &der.iterExportedProperties) {
		Trace.formatln("Property {}" ~ (prop.readOnly?" readOnly":"") ~ " {}", prop.name, prop.type.toString);
	}
	
	auto oth = new Other;
	oth.bindPropertyToRemote("text", der, "text");
	
	oth.text = "blah";
	assert (der.text == "blah");
	
	der.text = "zomg";
	Trace.formatln("{}", oth.text);
}
---
*/
module xf.hybrid.Property;

private {
	import tango.text.Util : isSpace;
}


/**
	Holds info about a wigdet property
*/
struct Property {
	char[]		name;		///
	TypeInfo	type;		///
	bool			readOnly;	///
	void delegate() function(Object, void delegate()) getterAccess;	///
	void delegate() function(Object, void delegate()) setterAccess;	///
}


void parsePropDef(in char[] def, out bool readOnly, out bool inlined, out char[] type, out char[] name) {
	if (def.length > 6 && def[0..6] == "inline") {
		inlined = true;
		def = def[6..$];
		while (isSpace(def[0])) {
			def = def[1..$];
		}
	}

	if (def[0..3] == "out") {
		readOnly = true;
		def = def[3..$];
		while (isSpace(def[0])) {
			def = def[1..$];
		}
	}
	
	int sep;
	foreach_reverse (i, c; def) {
		if (isSpace(c)) {
			sep = i;
			break;
		}
	}
	
	assert (sep != 0);
	name = def[sep+1 .. $];
	
	def = def[0..sep];
	while (isSpace(def[$-1])) {
		def = def[0..$-1];
	}
	type = def;
}


char[] defineProperty(char[] def) {
	bool readOnly, inlined;
	char[] type, name;	
	parsePropDef(def, readOnly, inlined, type, name);
	
	char[] result;
	
	if (!inlined) {
		result ~= "static if (is(typeof(&this." ~ name ~ "))) {"\n;
	}
	
	{
		if (!inlined) {
			result ~= "static if (!is(typeof(this." ~ name ~ "()) == " ~ type ~ ")) {"\n;
			result ~= "static assert (false, `In `~__FILE__~`(`~__LINE__.stringof~`): wrong prop '" ~ name ~ "' getter type (should be " ~ type ~ " "~name~"())`);"\n;
			result ~= "}"\n;
			
			if (!readOnly) {
				result ~= "static if (!is(typeof(this." ~ name ~ "((" ~ type ~ ").init)))) {"\n;
				result ~= "static assert (false, `In `~__FILE__~`(`~__LINE__.stringof~`): wrong prop '" ~ name ~ "' setter type (should be typeof(this) "~name~"(" ~ type ~ "))`);"\n;
				result ~= "}"\n;
			}
		} else {
			result ~= "protected " ~ type ~ " _" ~ name ~ ";"\n;
			result ~= type ~ " " ~ name ~ "() {"\n;
			result ~= "return _" ~ name ~ ";"\n;
			result ~= "}"\n;
			
			if (!readOnly) {
				result ~= "typeof(this) " ~ name ~ "(" ~ type ~ " newValue) {"\n;
				result ~= "_" ~ name ~ " = newValue;"\n;
				result ~= "return this;"\n;
				result ~= "}"\n;
			}
		}

		result ~= "private static void delegate() _propGetterAccess_" ~ name ~ "(Object o, void delegate() dg) {"\n;
		result ~= "assert (cast(typeof(this))o !is null, `_propGetterAccess_: o is null`);"\n;
		result ~= "assert(dg is null, `the property is statically bound`);"\n;
		result ~= "return cast(void delegate())cast(" ~ type ~ " delegate())&(cast(typeof(this))o)." ~ name ~ ";"\n;
		result ~= "}"\n;
		
		if (!readOnly) {
			result ~= "private static void delegate() _propSetterAccess_" ~ name ~ "(Object o, void delegate() dg) {"\n;
			//result ~= "assert (cast(typeof(this))o !is null);"\n;
			result ~= "assert (cast(typeof(this))o !is null, `_propSetterAccess_: o is null`);"\n;
			result ~= "assert(dg is null, `the property is statically bound`);"\n;
			result ~= "return cast(void delegate())cast(typeof(this) delegate("~type~"))&(cast(typeof(this))o)." ~ name ~ ";"\n;
			result ~= "}"\n;
		}
	}

	if (!inlined) {
		result ~= "} else {"\n;
		{
			result ~= "private " ~ type ~ " delegate() _propGetter_" ~ name ~ ";"\n;
			
			result ~= type ~ " " ~ name ~ "() {"\n;
			result ~= "return _propGetter_" ~ name ~ "();"\n;
			result ~= "}"\n;
			
			result ~= "private static void delegate() _propGetterAccess_" ~ name ~ "(Object o, void delegate() dg) {"\n;
			//result ~= "assert (cast(typeof(this))o !is null);"\n;
			result ~= "assert (cast(typeof(this))o !is null, `_propGetterAccess_2: o is null`);"\n;
			result ~= "if (dg !is null) (cast(typeof(this))o)._propGetter_" ~ name ~ " = cast("~type~" delegate())dg;";
			result ~= "return cast(void delegate())(cast(typeof(this))o)._propGetter_" ~ name ~ ";"\n;
			result ~= "}"\n;
			
			if (!readOnly) {
				result ~= "private Object delegate(" ~ type ~ ") _propSetter_" ~ name ~ ";"\n;
				result ~= "typeof(this) " ~ name ~ "(" ~ type ~ " newValue) {"\n;
				result ~= "_propSetter_" ~ name ~ "(newValue);"\n;
				result ~= "return this;\n}"\n;

				result ~= "private static void delegate() _propSetterAccess_" ~ name ~ "(Object o, void delegate() dg) {"\n;
				//result ~= "assert (cast(typeof(this))o !is null);"\n;
				result ~= "assert (cast(typeof(this))o !is null, `_propSetterAccess_2: o is null`);"\n;
				result ~= "if (dg !is null) (cast(typeof(this))o)._propSetter_" ~ name ~ " = cast(Object delegate(" ~ type ~ "))dg;";
				result ~= "return cast(void delegate())(cast(typeof(this))o)._propSetter_" ~ name ~ ";"\n;
				result ~= "}"\n;
			}
		}
		result ~= "}"\n;
	}
		
//	result ~= "private import tango.stdc.stdio : printf;\n";
	result ~= "static this() {"\n;
	result ~= "Property prop;"\n;
	result ~= "prop.name = \"" ~ name ~ "\";"\n;
	result ~= "prop.type = typeid(" ~ type ~ ");"\n;
	result ~= "prop.getterAccess = &typeof(this)._propGetterAccess_" ~ name ~ ";"\n;
	if (readOnly) {
		result ~= "prop.readOnly = true;"\n;
	} else {
		result ~= "prop.setterAccess = &typeof(this)._propSetterAccess_" ~ name ~ ";"\n;
	}
//	result ~= "printf(`adding prop %.*s to widget %.*s\n`, prop.name, typeof(this).stringof);\n";
	result ~= "_exportedProperties ~= prop;"\n;
	result ~= "}"\n;
	
	return result ~ \n;
}


char[] genStandardPropSupportCode() {
	char[] result = "private static Property[]	_exportedProperties;"\n;
	result ~= "override int iterExportedProperties(int delegate(ref Property) dg) {"\n;
	result ~= "if (auto res = super.iterExportedProperties(dg)) return res;"\n;
	result ~= "foreach (ref p; _exportedProperties) if (auto res = dg(p)) return res;"\n;
	result ~= "return 0;"\n;
	result ~= "}"\n;
	return result;
}



/**
	Generates code for quickly creating properties
	
	The argument should be a comma-separated list of properties of the form:
	[inline] [out] TYPE NAME
	
	If the property is 'inline', a variable will be created for it and called _NAME
	
	If the property is 'out', it will not get a writer and binding a writer to it will result in an error
*/
char[] defineProperties(char[] def) {
	char[] result = genStandardPropSupportCode();	
	{
		int from;
		bool inside = false;
		foreach (to, c; def) {
			if (' ' == c || '\t' == c) {
				if (!inside) {
					++from;
				}
			}
			else if (',' == c) {
				result ~= defineProperty(def[from .. to]);
				from = to+1;
				inside = false;
			} else {
				inside = true;
			}
		}
		
		if (inside) {
			result ~= defineProperty(def[from .. $]);
		}
	}
	
	return result;
}



/**
	Exposes an interface for querying and binding properties
*/
interface IPropertySupport {
	/**
		foreach-able property accessor
	*/
	int iterExportedProperties(int delegate(ref Property));
	
	/**
		Bind a non-inline local property to a remote one specified by its holder object and a name
	*/
	void bindPropertyToRemote(char[] localName, IPropertySupport o, char[] remoteName);
	
	/**
		Find a property and return its holder object and the property descriptor
	*/
	bool findProperty(char[] name, Property** prop, Object* obj);
}


/**
	Implements IPropertySupport in a way compatible with defineProperties
*/
template MPropertySupport() {
	int iterExportedProperties(int delegate(ref Property)) {
		return 0;
	}
	
	void bindPropertyToRemote(char[] localName, IPropertySupport o, char[] remoteName) {
		Property* localProp;
		Object localPropObj;
		this.findProperty(localName, &localProp, &localPropObj);
		assert (localProp !is null, "No such local property: " ~ localName);

		Property* remoteProp;
		Object remotePropObj;
		o.findProperty(remoteName, &remoteProp, &remotePropObj);
		assert (remoteProp !is null, "No such remote property: " ~ remoteName);

		assert (localProp.readOnly || !remoteProp.readOnly, "The remote property is read-only");
		
		assert (localProp.getterAccess !is null, "localProp.getterAccess is null");
		assert (remoteProp.getterAccess !is null, "remoteProp.getterAccess is null");
		localProp.getterAccess(localPropObj, remoteProp.getterAccess(remotePropObj, null));
		
		if (!localProp.readOnly) {
			assert (localProp.setterAccess !is null, "localProp.setterAccess is null");
			assert (remoteProp.setterAccess !is null, "remoteProp.setterAccess is null");
			localProp.setterAccess(localPropObj, remoteProp.setterAccess(remotePropObj, null));
		}
	}


	bool findProperty(char[] name, Property** prop, Object* obj) {
		int dpos = tango.text.Util.locate(name, '.');
		if (dpos < name.length) {
			char[] a = name[0..dpos];
			char[] b = name[dpos+1..$];
			
			if (auto sub = getSub(a)) {
				return sub.findProperty(b, prop, obj);
			} else {
				return false;
			}
		} else {
			foreach (ref p; &this.iterExportedProperties) {
				if (p.name == name) {
					*prop = &p;
					*obj = this;
					return true;
					//return &p;
				}
			}
			return false;
		}
	}
	
	
	/**
		Set the property named 'name' to the given value
	*/
	void setProperty(T)(char[] name, T val) {
		return .xf.hybrid.Property.setProperty!(T)(this, name, val);
	}


	/**
		Get the 'name' property's value
	*/
	T getProperty(T)(char[] name) {
		return .xf.hybrid.Property.getProperty!(T)(name);
	}
}



/**
	Set the property named 'name' inside the '_this' property holder to the given value
*/
void setProperty(T)(IPropertySupport _this, char[] name, T val) {
	Property*	prop;
	Object		obj;
	
	if (!_this.findProperty(name, &prop, &obj)) {
		throw new Exception("Unable to find property '" ~ name ~ "' in a " ~ (cast(Object)_this).classinfo.name);
	}
	
	if (prop.type !is typeid(T)) {
		throw new Exception("Proprty '" ~ name ~ "' is a " ~ prop.type.toString ~ ", not a " ~ typeid(T).toString);
	}
	
	if (prop.readOnly) {
		throw new Exception("Proprty '" ~ name ~ "' is read-only");
	}
	
	auto getter = cast(void delegate(T) function(Object, void delegate()))prop.setterAccess;
	assert (getter !is null, "tryCallProp_: getter is null");
	
	auto dg = getter(obj, null);
	assert (dg !is null, "tryCallProp_: dg is null");
	
	dg(val);
}


/**
	Get the 'name' property's value from the property holder '_this'
*/
T getProperty(T)(IPropertySupport _this, char[] name) {
	Property*	prop;
	Object		obj;
	
	if (!_this.findProperty(name, &prop, &obj)) {
		throw new Exception("Unable to find property '" ~ name ~ "' in a " ~ (cast(Object)_this).classinfo.name);
	}
	
	if (prop.type !is typeid(T)) {
		throw new Exception("Proprty '" ~ name ~ "' is a " ~ prop.type.toString ~ ", not a " ~ typeid(T).toString);
	}
	
	auto getter = cast(T delegate() function(Object, void delegate()))prop.getterAccess;
	assert (getter !is null, "tryCallProp_: getter is null");
	
	auto dg = getter(obj, null);
	assert (dg !is null, "tryCallProp_: dg is null");
	
	return dg();
}
