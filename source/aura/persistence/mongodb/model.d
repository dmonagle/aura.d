module aura.persistence.mongodb.model;

import aura.persistence.mongodb.adapter;
import aura.util.null_bool;
public import aura.persistence.core;

public import aura.data.bson;

import std.datetime;

/// Optional second template parameter is to specify the Store and mixes in the PersistenceStore property
mixin template MongoModel(ModelType, alias StoreType = null) {
	@optional BsonObjectID _id;
	mixin PersistenceTypeProperty;
	static if (!is(typeof(StoreType) == typeof(null))) {
		mixin PersistenceStoreProperty!StoreType;
	}

	@property const string _type() { return persistenceType; }
	// Dummy setter so that _type will be serialized
	@optional @property void _type(string value) {}
	
	@ignore @property BsonObjectID id() { return _id; } 
	@optional @property void id(BsonObjectID id) { _id = id; } 
	
	@ignore @property string persistenceId() const { return _id.to!string; }
	@property void persistenceId(string id) { _id = BsonObjectID.fromString(id); }
	
	@ignore @property bool isNew() { return !id.valid; }
	
	@property SysTime createdAt() {
		return id.timeStamp;
	}
	
	void ensureId() {
		if (!_id.valid) {
			_id = BsonObjectID.generate();
		}
	}
}

version(unittest) {
	
	struct PersistenceTestUser {
		string firstName;
		string surname;
		
		mixin MongoModel!PersistenceTestUser;
	}
	
	class PersistenceTestPerson {
		string name;
		
		mixin MongoModel!PersistenceTestPerson;
	}
	
	unittest {
		class TestMongoAdapter : MongoAdapter!(PersistenceTestUser, PersistenceTestPerson) {
			
		}
		auto mongodb = new TestMongoAdapter();
		mongodb.url = "mongodb://localhost";
		mongodb.database = "testdb_development";
		assert(mongodb.collectionPath("test") == "testdb_development.test");
		
		PersistenceTestUser u;
		u.firstName = "David";
		
		assert(u.isNew);
		mongodb.save(u);
		assert(!u.isNew);
		
		auto loadedUser = mongodb.findOne!PersistenceTestUser(u.id);
		assert(loadedUser.firstName == "David");
	}
	
	unittest {
		import std.exception;
		
		class TestMongoAdapter : MongoAdapter!(PersistenceTestUser, PersistenceTestPerson) {
			
		}
		auto mongodb = new TestMongoAdapter();
		mongodb.url = "mongodb://localhost";
		mongodb.database = "testdb_development";
		
		assert(mongodb.collectionPath("test") == "testdb_development.test");
		
		auto p = new PersistenceTestPerson;
		p.name = "David";
		
		assert(p.isNew);
		mongodb.save(p);
		assert(!p.isNew);
		
		auto loadedUser = mongodb.findOne!PersistenceTestPerson(p.id);
		assert(loadedUser.name == "David");
		
		assert(!mongodb.findOne!PersistenceTestPerson("000000000000000000000000"));
	}
}

void ensureEmbeddedMongoIds(M)(ref M model) {
	ensureEmbedded!((m) => m.ensureId)(model);
}

unittest {
	import std.stdio;
	import colorize;

	class Embedded : ModelInterface {
		mixin MongoModel!Embedded;
	}

	class TestModel : ModelInterface {
		mixin MongoModel!TestModel;

		@embedded Embedded embed;

		this() {
			embed = new Embedded;
		}
	}

	auto test = new TestModel;

	ensureEmbedded!((model) {
			model.ensureId;
			writeln(typeid(model).toString.color(fg.green));
			writeln(model.persistenceId.color(fg.yellow));
		})(test);
}
