/**
	* Graph Value
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.value.value;

import std.variant : Algebraic, visit, tryVisit;
import std.exception : enforce;

import std.typecons : Nullable;
import std.bigint;
import std.datetime : Date, SysTime;
import std.conv;
import std.traits;
import std.format;

import aura.data.bson;

import std.typetuple;

/// Basic Types used in GraphValue
alias GraphBasicTypes = TypeTuple!(
	bool,
	double,
	int,
	long,
	BigInt,
	string,
	Date,
	SysTime,
	BsonObjectID
	);

/**
 * Represents a generic Graph value.
 *
 * Wraps a $(D std.variant.Algebraic) to provide a way to represent a graph
 * of raw values.
 *
 * This is meant to be a little more expanisve than the general types held
 * by Json type structs and is aimed at field types commonly needed for 
 * databases.
 * 
 * Raw values can be one of: $(D null), $(D bool), $(D double), $(D string)
 * $(D Date), $(D SysTime)
 * Arrays are represented by $(D GraphValue[]) 
 * and objects by $(D GraphValue[string]).
*/
struct GraphValue {
	/**
     * Alias for a $(D std.variant.Algebraic) able to hold VariantStruct
     * value types.
     */
	
	alias Object = GraphValue[string];
	alias Array = GraphValue[];
	alias Types = TypeTuple!(GraphBasicTypes, TypeTuple!(typeof(null), Object, Array));
	alias Variant = Algebraic!Types;
	
	Variant value;

	alias value this;

	template holdsType(T) { enum holdsType = staticIndexOf!(T, Types) != -1 ? true : false; }

	/// Returns a GraphValue encapsulating an empty object
	static emptyObject() { return GraphValue(Object.init); }
	
	/// Returns a GraphValue encapsulating an empty array
	static emptyArray() { return GraphValue(Array.init); }
	
	/**
     * Constructs a GraphValue from the given raw value.
     */
	this(T : Variant)(T v) { value = v; }
	/// ditto
	this(T : GraphValue)(T v) { value = v.value; }
	/// ditto
	this(T : const U, U)(T v) {
        // Handle nullable types
        static if (__traits(compiles, v.isNull)) {
            if (v.isNull) value = null;
            else value = v.get;
        }
        else {
		  value = Variant(cast(U)v);
        }
	}
	/// ditto
	this(T)(T v) { 
		value = Variant(v);
	}

	
	/**
     * Gets a descendant of this value.
     *
     * If any encountered GraphValue along the path is not an object or does not
     * have a machting field, a null value is returned.
     */
	Nullable!GraphValue getPath(scope string[] path...)
	{
		GraphValue cur = this;
		foreach (name; path) {
			auto obj = cur.peek!(Object);
			if (!obj) return Nullable!GraphValue.init;
			auto pv = name in *obj;
			if (pv is null) return Nullable!GraphValue.init;
			cur = *pv;
		}
		return Nullable!GraphValue(cur);
	}

	/// Returns true if this $(D GraphValue) is of type T
	@property bool isType(T)() const {
		return value.peek!(T) ? true : false;
	}
	
	/// Returns true if this $(D GraphValue) is an object
	@property bool isObject() const {
		return isType!Object;
	}
	
	/// Returns true if this $(D GraphValue) is an array
	@property bool isArray() const {
		return isType!Array;
	}

	@property size_t length() const {
		if (isObject) return castObject.length;
		if (isArray) return castArray.length;
		return 0;
	}

	/// Returns true if this $(D GraphValue) is explicitly null or if it has no value
	@property bool isNull() const {
		if (!value.hasValue) return true;
		return isType!(typeof(null));
	}

	@property bool empty() const {
		return length ? false : true;
	}
	
	ref GraphValue opAssign(T : const U, U)(T value) 
		if (holdsType!U) 
	{
		this.value = cast(U)value;
		return this;
	}
	
	ref GraphValue opAssign(T)(T value) 
		if (holdsType!T) 
	{
		this.value = value;
		return this;
	}
	
	ref GraphValue opAssign(T : GraphValue)(T value) {
		this.value = value.value;
		return this;
	}
	
	ref inout(Array) castArray(string file = __FILE__, typeof(__LINE__) line = __LINE__) inout {
		auto asArray = value.peek!(Array);
		enforce(isArray, "Attempt to cast GraphValue to array but type is: " ~ value.type.stringof ~ ". (" ~ file ~ ":" ~ line.to!string ~")");
		return (*asArray);
	}
	
	ref inout(Object) castObject(string file = __FILE__, typeof(__LINE__) line = __LINE__) inout {
		auto asObject = value.peek!(Object);
		enforce(isObject, "Attempt to cast GraphValue to object but type is: " ~ value.type.stringof ~ ". (" ~ file ~ ":" ~ line.to!string ~")");
		return (*asObject);
	}
	
	ref GraphValue opIndex(size_t idx)
	{
		return castArray[idx];
	}

	bool hasKey(string key) const {
		if (!isObject) return false;
		auto asObject = value.peek!(Object);
		return key in (*asObject) ? true : false;
	}

	ref inout(GraphValue) opIndex(string key, string file = __FILE__, typeof(__LINE__) line = __LINE__) inout
	{
		enforce(isObject, format("GraphValue is not an object. Attempted index of key %s called from %s(%s)", key, file, line));
		auto asObject = value.peek!(Object);
		enforce(key in (*asObject), "Key not present in GraphValue Object: " ~ key ~ ". (" ~ file ~ ":" ~ line.to!string ~")");
		return (*asObject)[key];
	}

	void opIndexAssign(T)(T newValue, string key, string file = __FILE__, typeof(__LINE__) line = __LINE__) {
		enforce(isObject, "assigning to a key can only be called on an Object type, not " ~ value.type.stringof ~ ". (" ~ file ~ ":" ~ line.to!string ~")");
		(*value.peek!Object)[key] = newValue;
	}
	
	/// Creates a recursed duplicate, ensuring arrays and objects are duplicates and not slices
	GraphValue dup() {
		if (this.isArray) {
			Array array;
			foreach(v; value.get!Array) array ~= v.dup;
			return GraphValue(array);
		}
		else if (this.isObject) {
			Object object;
			foreach(k, v; value.get!Object) object[k] = v.dup;
			return GraphValue(object);
		}
		return GraphValue(value);
	}

	TT convert(TT, alias func)() {
		foreach(T; Types) {
			if (typeid(T) == value.type) return func(value.get!T);
		}
	}
	
	/// Appends the given element to the array. If the element is an array, it will be nested
	void append(T)(T newValue, string file = __FILE__, typeof(__LINE__) line = __LINE__)
	{
		enforce(isArray, "'append' can only be called on Array type, not " ~ value.type.stringof ~ ". (" ~ file ~ ":" ~ line.to!string ~")");
		(*value.peek!Array) ~= GraphValue(newValue);
	}
}

/// Shows the basic construction and operations on Graph values.
unittest
{
	GraphValue a = 12;
	GraphValue b = 13;
	
	assert(a == 12.0);
	assert(b == 13.0);
	assert(a + b == 25.0);
	
	auto c = GraphValue([a, b]);
	assert(c.isArray);
	assert(c.get!(GraphValue.Array)[0] == 12.0);
	assert(c.get!(GraphValue.Array)[1] == 13.0);
	assert(c[0] == a);
	assert(c[1] == b);
	static if (__VERSION__ < 2067) {
		assert(c[0] == 12.0);
		assert(c[1] == 13.0);
	}
	
	auto d = GraphValue(["a": a, "b": b]);
	assert(d.isObject);
	assert(d.get!(GraphValue.Object)["a"] == 12.0);
	assert(d.get!(GraphValue.Object)["b"] == 13.0);
	assert(d["a"] is a);
	assert(d["b"] is b);
}

/// Using $(D opt) to quickly access a descendant value.
unittest
{
	GraphValue subobj = ["b": GraphValue(1.0), "c": GraphValue(2.0)];
	GraphValue obj = ["a": subobj];
	
	assert(obj.getPath("x").isNull);
	assert(obj.getPath("a", "b") == 1.0);
	assert(obj.getPath("a", "c") == 2.0);
	assert(obj.getPath("a", "x").isNull);
}

unittest {
	GraphValue nullValue = null;
	assert(nullValue.isNull);
	assert(!nullValue.isType!int);

	GraphValue intValue = 5;
	assert(!intValue.isNull);
	assert(intValue.isType!int);
}

unittest {
	// Test setting a const

	GraphValue intValue = cast(const int)5;
	assert (intValue.get!int == 5);
}

unittest {
	GraphValue d = GraphValue.emptyObject;
	d["c"] = 22;
	assert(d["c"] == 22);
}
