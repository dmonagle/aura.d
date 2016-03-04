module aura.data.json.builder;

public import vibe.data.json;

class JsonBuilderBase {
	Json _json;

	@property Json json() {
		return _json;
	}
}

mixin template JsonBuilderCore(BuildClass) {
	static Json opCall(scope void delegate (BuildClass) buildPred = null) {
		auto m = new BuildClass();
		if (buildPred) buildPred(m);
		return m.json;
	}

	alias _json this;
}

class JsonObjectBuilder : JsonBuilderBase {
	mixin JsonBuilderCore!JsonObjectBuilder;

	this() {
		_json = Json.emptyObject;
	}
}

unittest {
	auto j = JsonObjectBuilder((j) {
		j.test = "Hello";
	});

	assert(is(typeof(j.json) == Json));
	assert(j.test.to!string == "Hello");
}
