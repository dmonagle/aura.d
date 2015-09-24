/**
	* Conversions for GraphValue
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.value.conv;

import aura.graph.value.value;
import std.conv;

T fromGraphValue(T)(const GraphValue value) {
	return value.get!T;
}


T fromGraphValue(T : double)(GraphValue value) {
	return value.tryVisit!(
		(int) => value.get!int.to!double,
		(long) => value.get!long.to!double,
		(string v) => value.get!string.to!double,
		() => double.nan
		);
}

unittest {
	auto v = GraphValue(29);
	assert(fromGraphValue!double(v) == 29.0);
}
/*
int fromGraphValue(GraphValue value) {
	return value.tryVisit!(
		(double) => cast(int)value.get!double,
		(int) => value.get!int,
		(long) => cast(int)value.get!long,
		() => int.init
		);
}
*/

GraphValue toGraphValue(T)(T value) 
if (GraphValue.holdsType!T) {
	return GraphValue(value);
}
