module aura.query.mongo.and;

import aura.data.json;

class MongoAnd : JsonBuilder {
	mixin JsonBuilderBase!MongoAnd;
	
	protected Json _json;
	
	this() {
		_json = Json.emptyArray;
	}
	
	MongoAnd add(T : Json)(T criteria) {
		_json ~= criteria;
		return this;
	}
	
	MongoAnd add(T)(T criteria) {
		return add(serializeToJson(criteria));
	}
	
	override @property Json json() {
		return _json.wrap("$and");
	}
	
}

unittest {
	auto m = new MongoAnd;
}

