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
	return (json.isInt || json.isFloat);
}


bool isUndefined(const ref Json json) {
	return json.type == Json.Type.undefined;
}

bool isNull(const ref Json json) {
	return json.type == Json.Type.null_;
}

