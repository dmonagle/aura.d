module aura.controllers.api.pathComponent;

import std.regex;

import vibe.web.web;
import vibe.http.router;
import vibe.core.log;

import colorize;

enum pathId = before!(pathComponentPred!(0))("_id");

// Extracts the numbered component from a URL path counting backwards from 0
string extractPathComponent(string url, int position) {
	auto m = matchAll(url, ctRegex!`\/([^\/\?]*)`);
	enforceHTTP(m, HTTPStatus.unprocessableEntity, "Could not locate required path parameter");
	string[] pathComponents;
	foreach(match; m) {
		pathComponents ~= match[1];
	}
	string captured = pathComponents[$ - (position + 1)];
	return captured;
}

/// Returns the path component at the specified position from the end (starting at 0)
string pathComponentPred(int position)(HTTPServerRequest req, HTTPServerResponse res) {
	auto captured = req.requestURL.extractPathComponent(position);
	logDebug("Capturing position %s from %s gives us %s", position, req.requestURL.color(fg.yellow), captured.color(fg.cyan));
	return captured;
}
