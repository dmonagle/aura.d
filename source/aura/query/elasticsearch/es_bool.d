module aura.query.elasticsearch.es_bool;

import aura.data.json;

class EsBool : JsonBuilderBase {
	mixin JsonBuilderCore!EsBool;
	
	this() {
		_json = Json.emptyObject;
		_json.must = Json.emptyArray;
		_json.must_not = Json.emptyArray;
		_json.should = Json.emptyArray;
	}
	
	EsBool must(T : Json)(T criteria) {
		_json.must ~= criteria;
		return this;
	}
	
	EsBool must(T : string)(T criteria) {
		return must(criteria.parseJsonString);
	}
	
	EsBool must(T)(T criteria) {
		return must(serializeToJson(criteria));
	}
	
	EsBool must_not(T : Json)(T criteria) {
		_json.must_not ~= criteria;
		return this;
	}
	
	EsBool must_not(T : string)(T criteria) {
		return must_not(criteria.parseJsonString);
	}

	EsBool must_not(T)(T criteria) {
		return must_not(serializeToJson(criteria));
	}
	
	EsBool should(T : Json)(T criteria) {
		_json.should ~= criteria;
		return this;
	}
	
	EsBool should(T : string)(T criteria) {
		return should(criteria.parseJsonString);
	}

	EsBool should(T)(T criteria) {
		return should(serializeToJson(criteria));
	}
	
	@property bool empty() {
		if (_json.must.length) return false;
		if (_json.must_not.length) return false;
		if (_json.should.length) return false;
		return true;
	}
	
	override @property Json json() {
		auto j = Json.emptyObject;
		
		if (_json.must.length) j.must = _json.must;
		if (_json.must_not.length) j.must_not = _json.must_not;
		if (_json.should.length) j.should = _json.should;
		
		return j;
	}
}

unittest {
	import std.stdio;
	import colorize;
	
	auto query = EsBool((b) {
		assert(b.empty);
		b.must(["David": "Ginny"]);
		b.should(["Tim": "Alison"]);
		//or.add(MongoOr.build.add(["nested": true]));
	});
	
	//writeln(query.toPrettyString.color(fg.green));
}

