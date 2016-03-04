module aura.util.escape_csv;

import std.regex;
import std.typecons;

string escapeCsvField(string field) {
	if(matchFirst(field, ctRegex!`[,"\n]`)) {
		auto escapedField = replaceAll(field, ctRegex!`"`, `""`);
		return `"` ~ escapedField ~ `"`;
	}
	return field;
}

unittest {
	assert(escapeCsvField(`one`) == `one`);
	assert(escapeCsvField(`two, with a comma`) == `"two, with a comma"`);
	assert(escapeCsvField(`"three with quotes"`) == `"""three with quotes"""`);
	assert(escapeCsvField(`four with "," a quoted comma`) == `"four with "","" a quoted comma"`);
	assert(escapeCsvField("five, with a \nnew line") == "\"five, with a \nnew line\"");
}

string escapeCsvField(Nullable!string field) {
	if (field.isNull)
		return "";
	if (!field.length)
		return `""`;
	return escapeCsvField(field.get);
}

unittest {
	Nullable!string s;
	assert(escapeCsvField(s) == "");
	
	s = "";
	assert(escapeCsvField(s) == `""`);
	
	s = "two, with a comma";
	assert(escapeCsvField(s) == `"two, with a comma"`);
}
