module aura.feature_test.shoulds;

debug (featureTest) {
	import aura.feature_test.feature_test;

	import std.string;

	import vibe.web.rest;
	import vibe.http.server;
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

	template should(alias operation, string description) {
		bool should(E)(lazy E expression, string name="Value", string file = __FILE__, typeof(__LINE__) line = __LINE__) {
			auto eValue = expression;
			if (operation(eValue)) return true;
			throw new FeatureTestException(format("%s should %s, but it was %s", name, description, eValue), file, line);
		}
	}

	template shouldValue(alias operation, string description) {
		bool shouldValue(E, V)(lazy E expression, V value, string name="Value", string file = __FILE__, typeof(__LINE__) line = __LINE__) {
			auto eValue = expression;
			if (operation(eValue, value)) return true;
			throw new FeatureTestException(format("%s should %s %s, but was actually %s", name, description, value, eValue), file, line);
		}
	}

	alias shouldBeTrue = should!((e) => e ? true : false, "be true");
	alias shouldBeFalse = should!((e) => e ? false : true, "be false");
	alias shouldEqual = shouldValue!((e, v) => e == v, "equal");
	alias shouldBeGreaterThan = shouldValue!((e, v) => e > v, "be greater than");
	alias shouldBeLessThan = shouldValue!((e, v) => e < v, "be less than");
	alias shouldNotBeEmpty = should!((e) => e.length ? true : false, "not be empty");

	import aura.data.json;
	/// Asserts the the given expression is of a specific Json type
	bool shouldBeJson(string type)(Json object, string file = __FILE__, typeof(__LINE__) line = __LINE__) {
		bool function(ref const Json) check = mixin("&is" ~ type);
		if (check(object)) return true;
		throw new FeatureTestException(format("Should be JSON type %s but got %s", type, object.type), file, line);
	}
}


