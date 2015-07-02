module aura.data.json.util;

public import vibe.data.json;

// Wraps the Json content in a new Json object with the specified key
Json wrap(Json content, string key) {
	auto j = Json.emptyObject;
	j[key] = content;
	return j;
}

unittest {
	auto j = Json.emptyObject;
	j.name = "Jenny";
	j.age = 21;
	
	auto w = j.wrap("person");
	
	assert(w.person.name == "Jenny");
	
	// The wrapped object contains the actual original object, not a duplicate
	w.person.name = "Jason";
	assert(j.name == "Jason");
}

/// Return true if the passed Json object is undefined or null
@property bool undefinedOrNull(const ref Json value) {
	import std.algorithm;
	
	return [Json.Type.null_, Json.Type.undefined].canFind(value.type);
}

// Returns a string from the JSON if the type is string, otherwise returns an empty string
string forceString(Json v) {
	if (v.type == Json.Type.string) return v.get!string;
	return "";
}

/// Deserializes many Json attributes to the corresponding attribute in the dest
void deserializeManyJson(T, mappings ...)(ref T dest, Json source) {
	import std.traits;
	import std.algorithm;
	import vibe.core.log;
	import std.algorithm;
	
	static assert(!(mappings.length % 2), "You must provide an even number of parameters for conversion (dest, source)");
	foreach (index, destAttr; mappings) {
		static if (!(index % 2)) {
			static if (mappings[index + 1].length)
				immutable string sourceAttr = mappings[index + 1];
			else
				immutable string sourceAttr = destAttr;
			auto sourceField = source[sourceAttr];
			logDebugV("Deserializing %s(%s) from JSON(%s)", destAttr, typeof(dest).stringof, sourceField.type);
			if (!undefinedOrNull(sourceField)) {
				deserializeJson(__traits(getMember, dest, destAttr), sourceField);
			}
			else {
				static if (__traits(compiles, __traits(getMember, dest, destAttr).isNull)) 
					__traits(getMember, dest, destAttr).nullify;
			}
		}
	}
}


bool jsonPresent(Json field) {
	import std.json;

	if (undefinedOrNull(field)) return false;
    if (field.type == Json.Type.string && !field.length) return false;
    return true;
}

unittest {
	auto json = [
		"thing"       : "stuff",
		"emptyString" : "",
		"isNull"      : null,
	].serializeToJson;

	json["zero"]   = 0;
	json["number"] = 2;
	json["object"] = ["hey": "yo"].serializeToJson;


	// truthy
	assert(jsonPresent(json["thing"]));
	assert(jsonPresent(json["number"]));
	assert(jsonPresent(json["zero"]));
	assert(jsonPresent(json["object"]));
	
	// falsey
	assert(!jsonPresent(json["emptyString"]));
	assert(!jsonPresent(json["isNull"]));
	assert(!jsonPresent(json["notDefined"]));
}