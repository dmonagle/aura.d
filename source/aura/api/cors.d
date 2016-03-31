module aura.api.cors;

import vibe.d;

/// Adds the Access-Control-Allow-Origin header to the response
void addAccessControlAllowOrigin(HTTPServerRequest req, HTTPServerResponse res) {
	if ("Origin" in req.headers) {
		res.headers["Access-Control-Allow-Origin"] = req.headers["Origin"];
	}
	else {
		res.headers["Access-Control-Allow-Origin"] = "*";
	}
	
	if (req.method == HTTPMethod.OPTIONS) {
		if ("Access-Control-Request-Method" in req.headers) res.headers["Access-Control-Allow-Methods"] = req.headers["Access-Control-Request-Method"];
		if ("Access-Control-Request-Headers" in req.headers) res.headers["Access-Control-Allow-Headers"] = req.headers["Access-Control-Request-Headers"];
	}
}

/// Handles an OPTIONS request by setting the AccessControlAllowOrigin header and sending 
/// an empty response
void handleOptionsRequest(HTTPServerRequest req, HTTPServerResponse res) {
	addAccessControlAllowOrigin(req, res);
	res.writeBody("");
}
