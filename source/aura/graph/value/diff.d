module aura.graph.value.diff;

import aura.graph.value;

/// Returns a new `GraphValue` with the differences between original and  changed
GraphValue diff(GraphValue original, GraphValue changed) {
	if (original.type != changed.type) {
		return changed;
	}
	
	if (original.isObject) {
		auto _diff = GraphValue.emptyObject;
		
		auto originalObject = original.castObject;
		auto changedObject = changed.castObject;
		foreach(string key, value; changed.castObject) {
			// register the difference if the value doesn't exist in the original
			if (!original.hasKey(key)) _diff[key] = changed[key];
			else {
				auto changed = diff(original[key], changed[key]);
				if (!changed.isNull) _diff[key] = changed;
			}
		}
		
		// Check for keys that have been removed
		foreach(string key, value; originalObject) {
			if (!changed.hasKey(key)) {
				_diff[key] = GraphValue(null);
			}
		}
					
		if (_diff.empty) return GraphValue(null);
		return _diff;
	} 
	else {
		if (original != changed) return changed;
		return GraphValue(null);
	}
	
	
}

unittest {
	GraphValue string1 = "hello";
	GraphValue string2 = "goodbye";
	
	assert(diff(string1, string2) == "goodbye");
	assert(diff(string1, string1) == null);
}

unittest {
	auto j1 = GraphValue.emptyObject;
	
	j1["name"] = "John";
	j1["surname"] = "Smith";
	j1["title"] = "Manager";
	j1["car"] = GraphValue.emptyObject;
	j1["car"]["make"] = "Ford";
	j1["car"]["model"] = "Escort";
	j1["scores"] = GraphValue.emptyArray;
	j1["scores"].append(8);
	j1["scores"].append(8);
	j1["scores"].append(10);
	j1["scores"].append(6);
	j1["scores"].append(6);
	
	
	auto j2 = GraphValue.emptyObject;
	j2["name"] = "Sarah";
	j2["surname"] = "Smith";
	j2["age"] = 65;
	j2["car"] = GraphValue.emptyObject;
	j2["car"]["make"] = "Ford";
	j2["car"]["model"] = "Falcon";
	j2["scores"] = GraphValue.emptyArray;
	j2["scores"].append(7);
	j2["scores"].append(10);
	j2["scores"].append(9);
	j2["scores"].append(6);
	j2["scores"].append(6);
	
	auto diffForward = diff(j1, j2);
	auto diffBackward = diff(j2, j1);

	assert(diffForward["title"] == null);
	assert(diffForward["age"] == 65);
	assert(diffForward["car"]["model"] == "Falcon");
	assert(!diffForward["car"].hasKey("Make"));
	
	assert(diffBackward["title"] == "Manager");
	assert(diffBackward["age"] == null);
	assert(diffBackward["car"]["model"] == "Escort");
	assert(!diffBackward["car"].hasKey("Make"));
	
	assert(diff(j1, j1) == null);
}

