module aura.data.json.dup;

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
	
	a["greeting"] = "hello";
	a["array"] = Json.emptyArray;
	a["array"] ~= 27;
	a["array"] ~= 45;
	auto o = Json.emptyObject;
	o["car"] = Json.emptyObject;
	o["car"]["doors"] = 4;
	a["array"] ~= o;
	
	auto b = jsonDup(a);
	
	assert(b.toString() == a.toString());
	
	b["greeting"] = "yo";
	assert(a["greeting"] == "hello");
	
	b["greeting"] = "yo";
	assert(a["greeting"] == "hello");
}
