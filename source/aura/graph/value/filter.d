module aura.graph.value.filter;

import aura.graph.value;
import aura.data.attribute_tree;

import std.conv;

GraphValue filterKeys(alias shouldInclude = (string[]) => true)(GraphValue original, string[] path = []) {
	import std.string;

    if (original.isObject) {
        GraphValue.Object filtered;
        foreach(string key, value; original.castObject) {
    		auto pathKey = path ~ key;
            if (shouldInclude(pathKey)) {
                filtered[key] = filterKeys!shouldInclude(value, pathKey);
            }            
             
        }
        return GraphValue(filtered);
    }
    else if (original.isArray) {
        GraphValue.Array filtered;
        foreach(ulong index, value; original.castArray) {
            auto pathKey = path ~ index.to!string;
            if (shouldInclude(pathKey)) 
                filtered ~= filterKeys!shouldInclude(value, pathKey);
        }
        return GraphValue(filtered);
    }
    else {
        return original;
    }
}

/// Returns a GraphValue without any of the keys specified with attributes
GraphValue filterOut(ref GraphValue original, AttributeTree attributes)
in { 
    assert(original.isObject); 
} 
body {	
	return original.filterKeys!((key) => !attributes.isLeaf(key));
}

/// Returns a GraphValue that only has keys that are part of the given attributes
GraphValue filterIn(ref GraphValue original, AttributeTree attributes) 
in { 
    assert(original.isObject); 
} 
body {	
	return original.filterKeys!((key) => attributes.exists(key));
}


unittest {
	auto model = GraphValue.emptyObject;
	
	model["make"] = "Ford";
	model["model"] = "Falcon";
	model["wholesale"] = 5;
	model["retail"] = 5000;
	model["engine"] = GraphValue.emptyObject;
	model["engine"]["capacity"] = 4000;
	model["engine"]["value"] = 100;
	
	auto filtered = model.filterOut(["wholesale", "retail", "engine.value"].serializeToAttributeTree);

	assert(filtered["make"] == "Ford");
	assert("wholesale" !in filtered.castObject);
	assert("retail" !in filtered.castObject);
	assert(filtered["engine"]["capacity"] == 4000);
	assert("value" !in filtered["engine"].castObject);
	assert(model["retail"] == 5000);
    
    filtered = model.filterIn(["model", "engine.capacity"].serializeToAttributeTree);
	
	assert(filtered["model"] == "Falcon");
	assert("make" !in filtered.castObject);
	assert(filtered["engine"]["capacity"] == 4000);
	assert("value" !in filtered["engine"].castObject);
}
