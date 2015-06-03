module aura.feature_test.shoulds;

debug (featureTest) {
	import aura.feature_test.feature_test;

	import vibe.web.rest;
	import vibe.http.server;

	import std.string;

	/// Calls the given expression and returns true if it throws a RestException with the given status
	bool shouldThrowRestException(E)(lazy E expression, HTTPStatus status, string file = __FILE__, typeof(__LINE__) line = __LINE__) {
		try {
			expression();
		}
		catch(RestException e) {
			if (e.status == status.to!int) return true;
			auto error = format("REST Exception occurred but returned %s(%s) instead of %s(%s)", e.status.to!HTTPStatus.to!string, e.status, status.to!string, status);
			throw new FeatureTestException(error, file, line);
		}
		throw new FeatureTestException(format("REST Exception did not occur when expecting %s(%s)", status.to!string, status), file, line);
	}

	import aura.data.json;
	bool shouldBeJson(string type)(Json object, string file = __FILE__, typeof(__LINE__) line = __LINE__) {
		bool function(ref const Json) check = mixin("&is" ~ type);
		if (check(object)) return true;
		throw new FeatureTestException(format("Should be JSON type %s but got %s", type, object.type), file, line);
	}
}