module aura.util.is_blank;

import std.traits;

bool isBlank(T)(ref T source) {
	static if (__traits(compiles, source.isNull)) {
		if (source.isNull) return true;
	}
	
	static if (is(T : string)) {
		if (source.length == 0) return true;
	}
	
	static if (isNumeric!T) {
		if (source == 0) return true;
	}

	return false;
}

unittest {
	import std.typecons;
	
	Nullable!string s;
	
	assert(s.isBlank);
	s = "";
	assert(s.isBlank);
	s = "Hello";
	assert(!s.isBlank);
}

unittest {
	import std.typecons;
	
	enum Test {
		empty,
		notEmpty
	}
	
	Nullable!Test nTest;
	Test test;
	
	assert(nTest.isBlank);
	assert(!test.isBlank);
	assert(test.isBlank!(v => v == Test.empty));
	assert(!test.isBlank!(v => v == Test.notEmpty));
	
}
