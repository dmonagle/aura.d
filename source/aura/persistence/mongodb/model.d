module aura.persistence.mongodb.model;

import aura.persistence.mongodb.adapter;
import aura.persistence.core;
import aura.util.null_bool;

import vibe.data.bson;

import std.datetime;

mixin template MongoModel(ModelType, string cName = "") {
	@optional BsonObjectID _id;
	
	@property const string _type() { return ModelType.stringof; }
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
		
		auto loadedUser = mongodb.findModel!PersistenceTestUser(u.id);
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
		
		auto loadedUser = mongodb.findModel!PersistenceTestPerson(p.id);
		assert(loadedUser.name == "David");
		
		assert(mongodb.find!PersistenceTestPerson("000000000000000000000000").type == Bson.Type.null_);
	}
}

void ensureEmbeddedMongoIds(M)(ref M model) {
	foreach (memberName; __traits(allMembers, M)) {
		//static if (isRWPlainField!(M, memberName) || isRWField!(M, memberName)) {
		static if (is(typeof(__traits(getMember, model, memberName)))) {
			static if (__traits(getProtection, __traits(getMember, model, memberName)) == "public") {
				alias member = TypeTuple!(__traits(getMember, M, memberName));
				alias embeddedUDA = findFirstUDA!(EmbeddedAttribute, member);
				static if (embeddedUDA.found) {
					auto embeddedModel = __traits(getMember, model, memberName);
					if (embeddedModel.isNotNull) {
						static if (isArray!(typeof(embeddedModel))) {
							foreach(ref m; embeddedModel) {
								m.ensureId(); // Ensure the ID of each model in the array
								ensureEmbeddedMongoIds(m); // Ensure any recursive Ids
							}
						} else {
							embeddedModel.ensureId();
							ensureEmbeddedMongoIds(embeddedModel);
						}
					}
				}
			}
		}
	}
}
