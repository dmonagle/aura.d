module aura.controllers.api.jsParams;

import aura.data.json;

import vibe.http.router;
import vibe.web.web;
import vibe.utils.dictionarylist;

import std.regex;

template jsParam(alias name) {
	enum jsParam = before!(jsParamPred!(name))("_" ~ name);
}

template jsParam(T, alias name) {
	enum jsParam = before!(jsParamPred!(T, name))("_" ~ name);
}

Json extractJSParam(DictionaryList!(string,true,16L) query, string paramName) {
	void extractJsonComponent(ref Json json, string key, string value) {
		if (!key.length) {
			// This is a straight JSON value
			json = Json(value);
			return;
		}

		auto reKeyName = ctRegex!(`^\[([^\]]*)\]`);
		auto matches = key.matchFirst(reKeyName);
		if (matches) {
			auto subKey = key[matches[0].length..$];
			auto valueKey = matches[1];
			if (valueKey.length == 0) {
				// This is an array
				if (json.type != Json.Type.array) json = Json.emptyArray;
				Json arrayValue;
				extractJsonComponent(arrayValue, subKey, value);
				json ~= arrayValue;
			}
			else {
				if (json.type != Json.Type.object) json = Json.emptyObject;
				extractJsonComponent(json[valueKey], subKey, value);
			}
		}
	}

	Json json = Json.emptyObject;

	foreach(key, value; query) {
		if (key.length >= paramName.length && key[0..paramName.length] == paramName) {
			extractJsonComponent(json, key[paramName.length..$], value);
		}
	}

	return json;
}

/// Extracts a query parameter in jQuery format into a Json Object
Json jsParamPred(string paramName)(HTTPServerRequest req, HTTPServerResponse res) {
	return req.query.extractJSParam(paramName);
}

/// Extracts a query parameter in jQuery format into a Json format and deserializes into template type
T jsParamPred(T, string paramName)(HTTPServerRequest req, HTTPServerResponse res) {
	T returnStruct;

	auto json = req.query.extractJSParam(paramName);
	try {
		returnStruct.deserializeJson(json);
	}
	catch (Exception e) {
		enforceHTTP(false, HTTPStatus.unprocessableEntity, "Invalid parameters: " ~ e.msg);
	}

	return returnStruct;
}
