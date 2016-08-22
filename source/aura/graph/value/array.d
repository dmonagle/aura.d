module aura.graph.value.array;

import aura.graph.value.value;

/// Returns a GraphValue of type array containing the same elements of the passed aray as GraphValue
GraphValue graphArray(T)(T[] a) {
	GraphValue.Array array;
	foreach(value; a) {
		array ~= GraphValue(value);
	}

	return GraphValue(array);
}


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
	
	auto part = array.dup;
	part[0].value = 5;
	assert(array[0] == 1);
	assert(part[0] == 5);
}