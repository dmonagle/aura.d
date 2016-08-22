module aura.data.bson.diff;

public import vibe.data.bson;

/**
 * 
 * 
 */
Bson bsonDiff(Bson original, Bson changed) {
	import std.stdio;
	import colorize;
	
	if (original.type != changed.type) {
		return changed;
	}
	
	switch(original.type) {
		case Bson.Type.object: {
			Bson _diff = Bson.emptyObject;
			
			foreach(string key, value; changed) {
				// register the difference if the value doesn't exist in the original
				if (original[key].isNull) _diff[key] = changed[key];
				else {
					auto changed = bsonDiff(original[key], changed[key]);
					if (!changed.isNull) _diff[key] = changed;
				}
			}
			
			// Check for keys that have been removed
			foreach(string key, value; original) {
				if (changed[key].isNull) {
					_diff[key] = null;
				}
			}
			
			if (_diff == Bson.emptyObject) return Bson(null);
			return _diff;
		} 
		default: {
			if (original != changed) return changed;
			return Bson(null);
		}
	}
	
	
}

unittest {
	Bson string1 = "hello";
	Bson string2 = "goodbye";
	
	assert(bsonDiff(string1, string2) == Bson("goodbye"));
	assert(bsonDiff(string1, string1).isNull);
}

unittest {
	import vibe.data.json;
	
	auto j1 = Json.emptyObject;
	
	j1["name"] = "John";
	j1["surname"] = "Smith";
	j1["title"] = "Manager";
	j1["car"] = Json.emptyObject;
	j1["car"]["make"] = "Ford";
	j1["car"]["model"] = "Escort";
	j1["scores"] = Json.emptyArray;
	j1["scores"] ~= 8;
	j1["scores"] ~= 8;
	j1["scores"] ~= 10;
	j1["scores"] ~= 6;
	j1["scores"] ~= 6;
	
	
	auto j2 = Json.emptyObject;
	j2["name"] = "Sarah";
	j2["surname"] = "Smith";
	j2["age"] = 65;
	j2["car"] = Json.emptyObject;
	j2["car"]["make"] = "Ford";
	j2["car"]["model"] = "Falcon";
	j2["scores"] = Json.emptyArray;
	j2["scores"] ~= 7;
	j2["scores"] ~= 10;
	j2["scores"] ~= 9;
	j2["scores"] ~= 6;
	j2["scores"] ~= 6;
	
	auto b1 = Bson.fromJson(j1);
	auto b2 = Bson.fromJson(j2);
	
	auto diffForward = bsonDiff(b1, b2);
	auto diffBackward = bsonDiff(b2, b1);
	
	assert(diffForward["title"].isNull);
	assert(diffForward["age"].to!long == 65);
	assert(diffForward["car"]["model"].get!string == "Falcon");
	assert(diffForward["car"]["make"].isNull);
	
	assert(diffBackward["title"].get!string == "Manager");
	assert(diffBackward["age"].isNull);
	assert(diffBackward["car"]["model"].get!string == "Escort");
	assert(diffBackward["car"]["make"].isNull);
	
	assert(bsonDiff(b1, b1).isNull);
}
