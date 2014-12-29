module aura.data.json;

public import vibe.data.json;

/// Duplicate the original Json struct 
Json jsonDup(alias shouldInclude = (string[]) => true)(Json original, string[] path = []) {
	import std.string;
	
	switch(original.type) {
		case Json.Type.object: {
			Json _copy = Json.emptyObject;
			foreach(string key, value; original) {
				auto pathKey = path ~ key;
				if (shouldInclude(pathKey)) 
					_copy[key] = jsonDup!shouldInclude(value, pathKey);
			}
			return _copy;
		} 
			
		case Json.Type.array: {
			Json _copy = Json.emptyArray;
			foreach(ulong index, value; original) {
				auto pathKey = path ~ index.to!string;
				if (shouldInclude(pathKey)) 
					_copy ~= jsonDup!shouldInclude(value, pathKey);
			}
			return _copy;
		} 
			
		default: 
			return original;
	}
}

unittest {
	auto a = Json.emptyObject;
	
	a.greeting = "hello";
	a.array = Json.emptyArray;
	a.array ~= 27;
	a.array ~= 45;
	auto o = Json.emptyObject;
	o.car = Json.emptyObject;
	o.car.doors = 4;
	a.array ~= o;
	
	auto b = jsonDup(a);
	
	assert(b.toString() == a.toString());
	
	b.greeting = "yo";
	assert(a.greeting == "hello");
	
	b.greeting = "yo";
	assert(a.greeting == "hello");
}

ref Json jsonFilterOutInPlace(const string separator = ".")(ref Json original, string[] filters ...) {
	import std.string;
	
	foreach(string key; filters) {
		auto filter = key.split(separator);
		
		// Is this a path?
		if (filter.length > 1) {
			auto nested = original[filter[0]];
			jsonFilterOutInPlace(nested, filter[1..$]);
		}
		else {
			original.remove(key);
		}
	}
	
	return original;
}

Json jsonFilterOut(const string separator = ".")(Json original, string[] filters ...) {
	auto copy = jsonDup(original);
	
	return jsonFilterOutInPlace!separator(copy, filters);
}

unittest {
	auto model = Json.emptyObject;
	
	model.make = "Ford";
	model.model = "Falcon";
	model.wholesale = 5;
	model.retail = 5000;
	model.engine = Json.emptyObject;
	model.engine.capacity = 4000;
	model.engine.value = 100;
	
	auto filtered = jsonFilterOut(model, "wholesale", "retail", "engine.value");
	assert(filtered.make == "Ford");
	assert("wholesale" !in filtered);
	assert("retail" !in filtered);
	assert(filtered.engine.capacity == 4000);
	assert("value" !in filtered.engine);
	
	assert(model.retail == 5000);
}

Json jsonFilterIn(const string separator = ".")(Json original, string[] filters ...) 
in { assert(original.type == Json.Type.object); } body {	
	import std.algorithm;
	import std.array;
	import std.string;
	
	auto splitFilters = array(filters.map!((f) => f.split(separator)));
	
	return jsonDup!(
		(key) {
		foreach(ulong index, string[] filter; splitFilters) {
			if (key.length < filter.length) filter = filter[0..key.length];
			if (key == filter) {
				return true;
			}
		}
		return false;
	}
	)(original);
}

unittest {
	auto model = Json.emptyObject;
	
	model.make = "Ford";
	model.model = "Falcon";
	model.wholesale = 5;
	model.retail = 5000;
	model.engine = Json.emptyObject;
	model.engine.capacity = 4000;
	model.engine.value = 100;
	
	auto filtered = jsonFilterIn(model, "model", "engine.capacity");
	
	assert(filtered.model == "Falcon");
	assert("make" !in filtered);
	assert(filtered.engine.capacity == 4000);
	assert("value" !in filtered.engine);
}

/**
 * 
 * 
 */
Json jsonDiff(Json original, Json changed) {
	if (original.type != changed.type) {
		return changed;
	}
	
	switch(original.type) {
		case Json.Type.object: {
			Json _diff = Json.emptyObject;
			
			foreach(string key, value; changed) {
				// register the difference if the value doesn't exist in the original
				if (!(key in original)) _diff[key] = changed[key];
				else {
					auto changed = jsonDiff(original[key], changed[key]);
					if (changed != null) _diff[key] = changed;
				}
			}
			
			// Check for keys that have been removed
			foreach(string key, value; original) {
				if (!(key in changed)) {
					_diff[key] = null;
				}
			}
			
			if (_diff == Json.emptyObject) return Json(null);
			return _diff;
		} 
		default: {
			if (original != changed) return changed;
			return Json(null);
		}
	}
	
	
}

unittest {
	Json string1 = "hello";
	Json string2 = "goodbye";
	
	assert(jsonDiff(string1, string2) == "goodbye");
	assert(jsonDiff(string1, string1) == null);
}

unittest {
	auto j1 = Json.emptyObject;
	
	j1.name = "John";
	j1.surname = "Smith";
	j1.title = "Manager";
	j1.car = Json.emptyObject;
	j1.car.make = "Ford";
	j1.car.model = "Escort";
	j1.scores = Json.emptyArray;
	j1.scores ~= 8;
	j1.scores ~= 8;
	j1.scores ~= 10;
	j1.scores ~= 6;
	j1.scores ~= 6;
	
	
	auto j2 = Json.emptyObject;
	j2.name = "Sarah";
	j2.surname = "Smith";
	j2.age = 65;
	j2.car = Json.emptyObject;
	j2.car.make = "Ford";
	j2.car.model = "Falcon";
	j2.scores = Json.emptyArray;
	j2.scores ~= 7;
	j2.scores ~= 10;
	j2.scores ~= 9;
	j2.scores ~= 6;
	j2.scores ~= 6;
	
	auto diffForward = jsonDiff(j1, j2);
	auto diffBackward = jsonDiff(j2, j1);
	
	assert(diffForward.title == null);
	assert(diffForward.age == 65);
	assert(diffForward.car.model == "Falcon");
	assert("Make" !in diffForward.car);
	
	assert(diffBackward.title == "Manager");
	assert(diffBackward.age == null);
	assert(diffBackward.car.model == "Escort");
	assert("Make" !in diffBackward.car);
	
	assert(jsonDiff(j1, j1) == null);
}

/**
 * 
 * 
 */
Json jsonMerge(Json original, Json changed) {
	if (original.type != changed.type) {
		return changed;
	}
	
	switch(original.type) {
		case Json.Type.object: {
			Json _merged = original;
			
			foreach(string key, value; changed) {
				// set the value if value doesn't exist in the original
				if (!(key in original)) _merged[key] = changed[key];
				else {
					_merged[key] = jsonMerge(original[key], value);
				}
			}
			
			return _merged;
		} 
		default: {
			return changed;
		}
	}
}

unittest {
	auto j1 = Json.emptyObject;
	
	j1.name = "John";
	j1.surname = "Smith";
	j1.title = "Manager";
	j1.car = Json.emptyObject;
	j1.car.make = "Ford";
	j1.car.model = "Escort";
	j1.scores = Json.emptyArray;
	j1.scores ~= 8;
	j1.scores ~= 8;
	j1.scores ~= 10;
	j1.scores ~= 6;
	j1.scores ~= 6;
	
	
	auto j2 = Json.emptyObject;
	j2.name = "Sarah";
	j2.surname = "Smith";
	j2.age = 65;
	j2.car = Json.emptyObject;
	j2.car.make = "Ford";
	j2.car.model = "Falcon";
	j2.scores = Json.emptyArray;
	j2.scores ~= 7;
	j2.scores ~= 10;
	j2.scores ~= 9;
	j2.scores ~= 6;
	j2.scores ~= 6;
	
	auto merged = jsonMerge(j1, j2);
	assert(merged.name == "Sarah");
	assert(merged.surname == "Smith");
	assert(merged.title == "Manager");
	assert(merged.age == 65);
	assert(merged.car.model == "Falcon");
}

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