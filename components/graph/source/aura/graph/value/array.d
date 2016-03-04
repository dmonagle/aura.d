module aura.graph.value.array;

import aura.graph.value.value;

/// Returns a GraphValue of type array containing GraphValues of the given args
GraphValue graphArray(T...)(T args) {
	GraphValue.Array array;
	foreach(int index, arg; args) {
		static if(is(T[index] == GraphValue)) array ~= arg;
		else array ~= GraphValue(arg);
	}

	return GraphValue(array);
}

unittest {
	auto array = graphArray(1, 2, 3, 4, 5);
	assert(array.isArray);
	assert(!array.isObject);
	import std.stdio;
	import colorize;
	
	writefln("Value: %s", array);
	assert(array[0] == 1);
	auto part = array.dup;
	part[0].value = 5;
	writefln("Array: %s", array);
	writefln("Part: %s", part);
}