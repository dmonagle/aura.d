module aura.data.json.convenience;

public import vibe.data.json;


bool isObject(const ref Json json) {
	return json.type == Json.Type.object;
}

bool isArray(const ref Json json) {
	return json.type == Json.Type.Array;
}

bool isString(const ref Json json) {
	return json.type == Json.Type.string;
}

bool isBool(const ref Json json) {
	return json.type == Json.Type.bool_;
}

bool isInt(const ref Json json) {
	return json.type == Json.Type.int_;
}

bool isFloat(const ref Json json) {
	return json.type == Json.Type.float_;
}

bool isNumber(const ref Json json) {
	return (isInt(json) || isFloat(json));
}

bool isUndefined(const ref Json json) {
	return json.type == Json.Type.undefined;
}

bool isNull(const ref Json json) {
	return json.type == Json.Type.null_;
}

/// Returns true if the Json object is not null or undefined
bool isValid(const ref Json json) {
    return (json.type != Json.Type.null_ && json.type != Json.Type.undefined);
}

bool isSet(const ref Json json) {
	return !(isNull(json) || isUndefined(json));
}
