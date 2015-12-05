module aura.data.json.filter;

import aura.data.json.dup;
import aura.data.json.convenience;
import aura.data.attribute_tree;

ref Json jsonFilterOutInPlace(const string separator = ".")(ref Json original, string[] filters ...) {
	import std.string;

	// Only work on objects
	if (!isObject(original)) return original;

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

/// Returns a Json object that only has keys that are part of the given attributes
Json filterIn(ref Json original, AttributeTree attributes) 
in { assert(original.type == Json.Type.object); } body {	
	return jsonDup!(
		(key) => attributes.exists(key)
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
	
	auto filtered = model.filterIn(["model", "engine.capacity"].serializeToAttributeTree);
	
	assert(filtered.model == "Falcon");
	assert("make" !in filtered);
	assert(filtered.engine.capacity == 4000);
	assert("value" !in filtered.engine);
}

/// Returns a Json object without any of the keys specified with attributes
Json filterOut(ref Json original, AttributeTree attributes)
in { assert(original.type == Json.Type.object); } body {	
	return jsonDup!(
		(key) => !attributes.isLeaf(key)
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
	
	auto filtered = model.filterOut(["wholesale", "retail", "engine.value"].serializeToAttributeTree);
	assert(filtered.make == "Ford");
	assert("wholesale" !in filtered);
	assert("retail" !in filtered);
	assert(filtered.engine.capacity == 4000);
	assert("value" !in filtered.engine);
	
	assert(model.retail == 5000);
}

/// Removes any keys from the Json struct that don't meet the keyFilter requirement
void filterKeys(alias keyFilter = (string[]) => true)(ref Json original, string[] path = []) {
	switch(original.type) {
		case Json.Type.object: 
			foreach(string key, value; original) {
				auto pathKey = path ~ key;
				if (!keyFilter(pathKey)) original.remove(key);
				else filterKeys!(keyFilter)(value, pathKey);
			}
			break;
			
		case Json.Type.array: 
			foreach(ulong index, value; original) {
				auto pathKey = path ~ index.to!string;
				filterKeys!(keyFilter)(value, pathKey);
			}
			break;

		default: {}
	}
}

unittest {
	auto testJson = `
		{
			"name": "hello",
			"score": 10,
			"subjects": [
				{
					"name": "Math",
					"score": 9
				},
				{
					"name": "IT",
					"score": 10
				}
			]
		}
	`.parseJsonString;

	testJson.filterKeys!((key) { 
			return key[$ - 1] != "score";
		});
}
