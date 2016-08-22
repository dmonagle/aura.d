/**
	* Conversions for GraphValue
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.value.conv;

import aura.graph.value.value;
import vibe.data.json;

import std.bigint;
import std.typetuple;

import std.conv;

T fromGraphValue(T)(const GraphValue value) {
	return value.get!T;
}


T fromGraphValue(T : double)(GraphValue value) {
	return value.tryVisit!(
		(double) => value.get!double,
		(int) => value.get!int.to!double,
		(long) => value.get!long.to!double,
		(string v) => value.get!string.to!double,
		() => double.nan
		);
}

unittest {
	auto v = GraphValue(29);
	assert(fromGraphValue!double(v) == 29.0);
}
/*
int fromGraphValue(GraphValue value) {
	return value.tryVisit!(
		(double) => cast(int)value.get!double,
		(int) => value.get!int,
		(long) => cast(int)value.get!long,
		() => int.init
		);
}
*/

GraphValue toGraphValue(T : Json)(const ref T value) {
    final switch(value.type) {
        case Json.Type.undefined: 
        case Json.Type.null_: 
            return GraphValue(null); 
        case Json.Type.bool_: 
            return GraphValue(value.get!bool); 
        case Json.Type.int_: 
            return GraphValue(value.get!int); 
        case Json.Type.bigInt: 
            return GraphValue(value.get!BigInt); 
        case Json.Type.float_: 
            return GraphValue(cast(double)value.get!float); 
        case Json.Type.string: 
            return GraphValue(value.get!string); 
        case Json.Type.array:
            GraphValue.Array vArray; 
            foreach(jValue; value) 
                vArray ~= toGraphValue(jValue);
            return GraphValue(vArray); 
        case Json.Type.object:
            GraphValue.Object vObject; 
            foreach(string key, jValue; value) 
                vObject[key] = toGraphValue(jValue);
            return GraphValue(vObject); 
    }
} 

unittest {
    Json testJson = `{"dayOfWeek": "Wednesday", "day": 5}`.parseJsonString;
    
    auto value = toGraphValue(testJson);
    assert(value["dayOfWeek"].get!string == "Wednesday");
    assert(value["day"].get!int == 5);
}


GraphValue toGraphValue(T)(T value) 
if (GraphValue.holdsType!T) {
	return GraphValue(value);
}

Json toJson(const GraphValue value) {
	if (value.isNull) {
		return Json(null);
	}
	if (value.isObject) {
		auto json = Json.emptyObject;
		foreach(k, v; value.get!(GraphValue.Object)) json[k] = v.toJson;
		return json;
	}
	else if (value.isArray) {
        auto json = Json.emptyArray;
		foreach(v; value.castArray) json ~= v.toJson;
		return json;
	}

	foreach(Type; GraphBasicTypes) {
		if (value.isType!Type) return value.get!Type.serializeToJson;
	}

	return Json(null);
}

unittest {
    void toJsonTest(T)(T value, Json.Type jsonType) {
        GraphValue v = GraphValue(value);
        assert(v.toJson.type == jsonType);
        assert(v.toJson == Json(value));
    }
    
    toJsonTest(null, Json.Type.null_);
    toJsonTest(true, Json.Type.bool_);
    toJsonTest(10.2, Json.Type.float_);
}
