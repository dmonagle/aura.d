module aura.graph.mongodb.bson;

import aura.graph.value;
import vibe.data.bson;

import std.variant : tryVisit;
import std.bigint;
import std.datetime : Date, SysTime;
import std.typetuple;

Bson toBson(const GraphValue value) {
	if (value.isNull) {
		return Bson(null);
	}
	if (value.isObject) {
		auto bson = Bson.emptyObject;
		foreach(k, v; value.get!(GraphValue.Object)) bson[k] = v.toBson;
		return bson;
	}
	else if (value.isArray) {
        Bson[] values;
		foreach(v; value.get!(GraphValue.Array)) values ~= v.toBson;
		return values.serializeToBson;
	}

	if (value.type ==typeid(BsonObjectID)) return Bson(value.get!(BsonObjectID));
	foreach(Type; TypeTuple!(bool, double, int, long, string)) {
		if (value.type ==typeid(Type)) return Bson(value.get!Type);
	}
	if (value.type ==typeid(BigInt)) return Bson(value.get!(BigInt).toLong);
	if (value.type ==typeid(Date)) return Bson(value.get!(Date).toISOExtString);
	if (value.type ==typeid(SysTime)) return Bson(BsonDate(value.get!(SysTime)));


	return Bson(null);
}

unittest {
	// Integer Test
	auto gvInt = GraphValue(5);
	auto bsonInt = gvInt.toBson;
	assert (bsonInt.type == Bson.Type.int_);
	assert (bsonInt.get!int == 5);
	
	// Long Test
	auto gvLong = GraphValue(8080L);
	auto bsonLong = gvLong.toBson;
	assert (bsonLong.type == Bson.Type.long_);
	assert (bsonLong.get!long == 8080L);
	
	// Double Test
	auto gvDouble = GraphValue(3.14);
	auto bsonDouble = gvDouble.toBson;
	assert (bsonDouble.type == Bson.Type.double_);
	assert (bsonDouble.get!double == 3.14);
	
	// Date Test
	auto testDate = Date(2013, 3, 25);
	auto gvDate = GraphValue(testDate);
	auto bsonDate = gvDate.toBson;
	assert (bsonDate.type == Bson.Type.string);
	Date dDate;
	dDate.deserializeBson(bsonDate);
	assert (dDate == testDate);
	
	// SysTime Test
	import std.datetime : DateTime;
	auto testSysTime = SysTime(DateTime(2013, 3, 25, 13, 07, 11));
	auto gvSysTime = GraphValue(testSysTime);
	auto bsonSysTime = gvSysTime.toBson;
	assert (bsonSysTime.type == Bson.Type.date);
	SysTime dSysTime;
	dSysTime.deserializeBson(bsonSysTime);
	assert (dSysTime == testSysTime);

	GraphValue object = GraphValue.emptyObject;
	object["one"] = 1;

	// Object Test
	auto bsonObject = object.toBson;
	assert (bsonObject.type == Bson.Type.object);
}

// Test BsonObjectId comparison
unittest {
	auto bsonId = BsonObjectID.generate;
	auto graphId = GraphValue(bsonId);

	assert(bsonId == graphId);
}
