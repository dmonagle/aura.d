module aura.query.elasticsearch.es_bool;

import aura.data.json;
import std.format;

private string defineEsBoolOccurences(string[] occurenceTypes) {
    string returnString;
    foreach(occurenceType; occurenceTypes) {
        returnString ~= format(`EsBool %1$s(T)(T criteria) { return addOccurence!("%1$s")(criteria); }`, occurenceType);
    }
    return returnString;
}

class EsBoolTemplate(string[] occurenceTypes) : JsonBuilderBase {
	mixin JsonBuilderCore!EsBool;
    mixin (defineEsBoolOccurences(occurenceTypes));
	
	this() {
		_json = Json.emptyObject;
        foreach(occurenceType; occurenceTypes) {
            _json[occurenceType] = Json.emptyArray;
        }
	}
    	
	@property bool empty() {
        foreach(occurenceType; occurenceTypes) {
    		if (_json[occurenceType].length) return false;
        }
		return true;
	}
	
	override @property Json json() {
		auto j = Json.emptyObject;
		
        foreach(occurenceType; occurenceTypes) {
	    	if (_json[occurenceType].length) j[occurenceType] = _json[occurenceType];
        }
		
		return j;
	}

protected:
	EsBool addOccurence(string occurenceType, T : Json)(T criteria) {
		_json[occurenceType] ~= criteria;
		return this;
	}
	
	EsBool addOccurence(string occurenceType, T : string)(T criteria) {
		return addOccurence!occurenceType(criteria.parseJsonString);
	}
	
	EsBool addOccurence(string occurenceType, T)(T criteria) {
		return addOccurence!occurenceType(serializeToJson(criteria));
	}
}

alias EsBool = EsBoolTemplate!(["must", "filter", "should", "should_not"]);

unittest {
	auto query = EsBool((b) {
		assert(b.empty);
		b.must(["David": "Ginny"]);
		b.should(["Tim": "Alison"]);
		b.filter(["Jo": true]);
		b.filter(["Mia": false]);
		//or.add(MongoOr.build.add(["nested": true]));
	});
}

