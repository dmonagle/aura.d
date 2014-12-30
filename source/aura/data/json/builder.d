module aura.data.json.builder;

public import vibe.data.json;

class JsonBuilder {
	abstract @property Json json();
}

mixin template JsonBuilderBase(BuildClass) {
	static BuildClass build(void delegate (BuildClass) buildPred = null) {
		auto m = new BuildClass();
		if (buildPred) buildPred(m);
		return m;
	}
	
	alias json this;
}

