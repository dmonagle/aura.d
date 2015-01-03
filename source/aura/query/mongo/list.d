module aura.query.mongo.list;

import aura.data.json;

class MongoList(string op) : JsonBuilderBase {
	mixin JsonBuilderCore!(MongoList!op);
	
	protected Json _list;
	
	this() {
		_json = Json.emptyArray;
	}
	
	MongoList!op add(T : Json)(T criteria) {
		_json ~= criteria;
		return this;
	}
	
	MongoList!op add(T : string)(T criteria) {
		return add(criteria.parseJsonString);
	}

	MongoList!op add(T)(T criteria) {
		return add(serializeToJson(criteria));
	}

	override @property Json json() {
		return _json.wrap(op);
	}
}

unittest {
	auto j = MongoList!"$list"((l) {
		l.add(["value": 1]);
		l.add(["value": 2]);
	});

	auto list = j["$list"];
	assert(list.type == Json.Type.Array);
	assert(list.length == 2);
	assert(list[0].value.to!int == 1);
	assert(list[1].value.to!int == 2);
}

