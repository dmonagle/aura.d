/**
	* `Helpers for GraphValue`
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.value.helpers;

import aura.graph.value.value;

/// Creates a new `GraphValue` with the attributes of original merged with changed
GraphValue merge(GraphValue original, GraphValue changed) {
	if (original.isObject) {
		GraphValue _merged = original;
		foreach(key, value; changed.get!(GraphValue.Object)) {
			// set the value if value doesn't exist in the original
			if (!original.hasKey(key)) _merged[key] = changed[key];
			else {
				_merged[key] = merge(original[key], value);
			}
		}
		return _merged;
	}
	else {
		return changed;
	}
}

unittest {
	auto j1 = GraphValue.emptyObject;
	
	j1["name"] = "John";
	j1["surname"] = "Smith";
	j1["title"] = "Manager";
	j1["car"] = GraphValue.emptyObject;
	j1["car"]["make"] = "Ford";
	j1["car"]["model"] = "Escort";
	j1["car"]["seats"] = 4;
	j1["scores"] = GraphValue.emptyArray;
	j1["scores"].append(8);
	j1["scores"].append(8);
	j1["scores"].append(10);
	j1["scores"].append(6);
	j1["scores"].append(6);
	
	
	auto j2 = GraphValue.emptyObject;
	j2["name"] = "Sarah";
	j2["age"] = 65;
	j2["car"] = GraphValue.emptyObject;
	j2["car"]["model"] = "Falcon";
	j2["scores"] = GraphValue.emptyArray;
	j2["scores"].append(7);
	j2["scores"].append(10);
	j2["scores"].append(9);
	j2["scores"].append(6);
	j2["scores"].append(6);
	
	auto merged = merge(j1, j2);
	assert(merged["name"] == "Sarah");
	assert(merged["surname"] == "Smith");
	assert(merged["title"] == "Manager");
	assert(merged["age"] == 65);
	assert(merged["car"]["make"] == "Ford");
	assert(merged["car"]["model"] == "Falcon");
	assert(merged["car"]["seats"] == 4);
}