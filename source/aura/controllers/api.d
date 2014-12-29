module aura.controllers.api;

import std.regex;

import aura.data.bson;
import aura.data.json;

import vibe.web.web;
import vibe.http.router;
import vibe.core.log;

import colorize;

enum pathId = before!(pathComponentPred!(0))("_id");

/// Returns the path component at the specified position from the end (starting at 0)
string pathComponentPred(int position)(HTTPServerRequest req, HTTPServerResponse res) {
	auto m = matchAll(req.requestURL, ctRegex!`\/([^\/\?]*)`);
	enforceHTTP(m, HTTPStatus.unprocessableEntity, "Could not locate required path parameter");
	string[] pathComponents;
	foreach(match; m) {
		pathComponents ~= match[1];
	}
	string captured = pathComponents[$ - (position + 1)];
	logDebug("Capturing position %s from %s gives us %s", position, req.requestURL.color(fg.yellow), captured.color(fg.cyan));
	return captured;
}

struct ApiModelParams {
	Json params;
	const Bson originalObject;
	
	private Json _filteredParams;
	
	this (Json params, const Bson originalObject = Bson.emptyObject) {
		this.params = params;
		this.originalObject = originalObject;
		
		resetFilters;
	}
	
	ref ApiModelParams resetFilters() {
		this._filteredParams = jsonDup(params);
		return this;
	}
	
	ref ApiModelParams filterIn(string[] filters ...) {
		_filteredParams = _filteredParams.jsonFilterIn(filters);
		return this;
	}
	
	ref ApiModelParams filterOut(string[] filters ...) {
		_filteredParams.jsonFilterOutInPlace(filters);
		return this;
	}
	
	/// Returns true if the field has been changed. This will return false if the field has already been
	/// filtered out.
	bool fieldChanged(string field) {
		if (_filteredParams[field].type == Json.Type.undefined) return false;
		auto bsonField = updates[field];
		return updates[field] != originalObject[field];
	}
	
	/// Returns a Bson representation of the updates to be applied to the original object
	@property Bson updates() {
		auto u = Bson.fromJson(_filteredParams);
		return u;
	}
	
	/// Returns the Bson of the updates merged with the original object
	@property Bson merged() {
		return bsonMerge(originalObject, updates);
	}
}

unittest {
	auto bson = Bson.emptyObject;
	bson.firstName = "David";
	bson.surname = "Monagle";
	bson.level = 17;
	
	auto params = Json(["level": Json(20)]);
	
	auto modelParams = ApiModelParams(params, bson);
	assert(modelParams.fieldChanged("level"));
	assert(!modelParams.fieldChanged("nonExistant"));
	assert(modelParams.merged.level.to!long == 20);
	
	modelParams.filterOut("level");
	assert(!modelParams.fieldChanged("level"));
	assert(modelParams.updates.level.type == Bson.Type.null_);
	assert(modelParams.merged.level.to!int == 17);
}