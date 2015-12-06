module aura.data.json.safe_deserialize;

import aura.data.json.util;
import vibe.core.log;

import std.format;
import colorize;

bool safeDeserialize(D)(ref D destination, Json json, string file = __FILE__, typeof(__LINE__) line = __LINE__) {
	if (undefinedOrNull(json)) return false;
	try {
		deserializeJson(destination, json);
		return true;
	}
	catch (Exception e) {
		logError("Failed to deserialize %s into %s: %s:%s".color(fg.light_red), json.type, D.stringof, file, line);
		return false;
	}
}