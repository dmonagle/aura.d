module aura.util.clear_value;

import std.traits;

// Clears the given variable. Sets enums back to value 0, strings to emtpy strings and nullable types to null.
void clearValue(T)(ref T source) {
	static if (is(T == enum)) {
		source = cast(T)0;
	}
	static if (__traits(compiles, source.isNull)) {
		source.nullify;
	}
	static if (is(T == string)) {
		source = "";
	}
}

