module aura.util.null_bool;

public import std.typecons;
import std.traits;

bool isTrue(Nullable!bool b) {
	if (b.isNull) return false;
	return b.get;
}

bool isFalse(Nullable!bool b) {
	if (b.isNull) return true;
	return !b.get;
}

bool isNull(T)(ref T value) {
	static if (is(T == class))
		return value ? false : true;
	else static if (hasMember!(T, "isNull"))
		return value.isNull;
	else 
		return false;
}

bool isNotNull(T)(T value) {
	return !isNull(value);
}

unittest {
	string test;
	assert(test.isNotNull);
	
	Nullable!string testNullable;
	assert(testNullable.isNull);
	testNullable = "v";
	assert(testNullable.isNotNull);
	
	class TestClass {
	}
	
	TestClass c;
	assert(c.isNull);
	assert(isNull(c));
	c = new TestClass;
	assert(!c.isNull);
	assert(!isNull(c));
	assert(c.isNotNull);
}

unittest {
	Nullable!bool b;
	
	assert(b.isNull);
	assert(b.isFalse);
	assert(!b.isTrue);
	
	b = true;
	assert(!b.isFalse);
	assert(b.isTrue);
	
	b = false;
	assert(b.isFalse);
	assert(!b.isTrue);
}