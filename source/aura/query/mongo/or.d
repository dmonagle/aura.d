module aura.query.mongo.or;

import aura.data.json;

class MongoOr : JsonBuilder {
	mixin JsonBuilderBase!MongoOr;
	
	protected Json _json;
	
	this() {
		_json = Json.emptyArray;
	}
	
	MongoOr add(T : Json)(T criteria) {
		_json ~= criteria;
		return this;
	}
	
	MongoOr add(T)(T criteria) {
		return add(serializeToJson(criteria));
	}
	
	override @property Json json() {
		return _json.wrap("$or");
	}
	
}

unittest {
	import std.stdio;
	import colorize;
	
	auto m = new MongoOr;
	//writeln(MongoOr.build.add(["hello": "goodbye"]).add(["one": 2]).toPrettyString);
}

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
	auto m = new MongoOr;
}

