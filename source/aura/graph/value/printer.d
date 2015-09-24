module aura.graph.value.printer;

import aura.graph.value.value;

import std.stdio;
import colorize;

void print(GraphValue value, int indent = 0, bool repressIndent = false) {
	string tabs(int number, bool repressIndent = false) {
		if (repressIndent) return "";
		string tabString;
		for(auto count = 0; count < number; ++count) tabString ~= "    ";
		return tabString;
	}

	if (value.isObject) {
		writeln(tabs(indent, repressIndent), "{".color(fg.light_cyan));
		auto graphObject = value.get!(GraphValue.Object);
		foreach(string key, GraphValue v; graphObject) {
			writef("%s%s: ", tabs(indent + 1), key);
			v.print(indent + 1, true);
		}
		writeln(tabs(indent), "}".color(fg.light_cyan));
	}
	else if (value.isArray) {
		writeln(tabs(indent, repressIndent), "[".color(fg.light_cyan));
		foreach(GraphValue v; value) v.print(indent + 1);
		writeln(tabs(indent), "]".color(fg.light_cyan));
	}
	else {
		import std.datetime;
		auto pColor = fg.light_yellow;
		if (value.isType!string) pColor = fg.light_magenta;
		else if (value.isType!Date) pColor = fg.blue;

		writefln("%s%s".color(pColor), tabs(indent, repressIndent), value);
	}
}

unittest {
	import aura.graph.value.array;
	import std.datetime;

	auto car = GraphValue([
			"make": GraphValue("Audi"),
			"model": GraphValue("A4"),
			"year": GraphValue(2001),
		]);

	auto person = GraphValue([
			"name": GraphValue("David"),
			"dateOfBirth": GraphValue(Date(1979, 4, 17)),
			"age": GraphValue(27),
			"car": car,
			"scores": graphArray(1, 2, 3, 4, 5)
		]);


	auto gv = graphArray("Hello", 24, person);
	gv.append(graphArray("This", "is", "a", "nested", "array"));

	gv.print;
}