module aura.data.json.diff;

public import vibe.data.json;

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
	
	auto diffForward = jsonDiff(j1, j2);
	auto diffBackward = jsonDiff(j2, j1);
	
	assert(diffForward["title"] == null);
	assert(diffForward["age"] == 65);
	assert(diffForward["car"]["model"] == "Falcon");
	assert("Make" !in diffForward["car"]);
	
	assert(diffBackward["title"] == "Manager");
	assert(diffBackward["age"] == null);
	assert(diffBackward["car"]["model"] == "Escort");
	assert("Make" !in diffBackward["car"]);
	
	assert(jsonDiff(j1, j1) == null);
}

