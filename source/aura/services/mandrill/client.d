module aura.services.mandrill.client;

import vibe.http.client;
import vibe.http.common;
import vibe.core.log;
import vibe.stream.operations;

import aura.data.json;

import std.string;

class Client {
	private {
		string _apiKey;
	}

	this(string apiKey) {
		_apiKey = apiKey;
	}

	void request(string method, Json requestBody,
			scope void delegate(scope Json) responder
		) {
		HTTPResponse response;

		auto requestUrl = format("https://mandrillapp.com/api/1.0/%s.json", method);
		logInfo("Connecting to: %s", requestUrl);

		requestBody["key"] = _apiKey;

		requestHTTP(requestUrl,
			(scope req) {
				req.method = HTTPMethod.POST;
				req.headers["Content-Type"] = "application/json";
				req.writeJsonBody(requestBody);
			},
			(scope res) {
				if (res.statusCode >= 200 && res.statusCode < 300) {
					auto jsonPayload = res.readJson;
					responder(jsonPayload);
				}
				else {
					auto jsonPayload = res.readJson;
					logError("Error from Mandrill API");
					logError("Response: %s", jsonPayload.toPrettyString);
				}
			}
		);
	}
}

