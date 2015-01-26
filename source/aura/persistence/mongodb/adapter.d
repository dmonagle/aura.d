module aura.persistence.mongodb.adapter;

import aura.persistence.core;
import aura.persistence.mongodb.model;

public import vibe.db.mongo.mongo;
public import vibe.data.bson;
public import vibe.core.log;

public import std.datetime;

class MongoAdapter(M ...) : PersistenceAdapter!M {
	private {
		MongoClient _client;
		string _url;
		bool _connected;
	}
	
	@property bool connected() const { return _connected; }
	
	@property MongoClient client() {
		if (!connected) {
			_client = connectMongoDB(_url);
			_connected = true;
		}
		return _client;
	}
	
	@property ref string url() { return _url; }
	
	@property MongoDatabase database() {
		assert(_databaseName.length, "Property databaseName must not be empty");
		return client.getDatabase(_databaseName);
	}
	
	@property void database(string name) {
		_databaseName = name;
	}
	
	this() {
	}
	
	MongoCollection getCollection(string collection) {
		return client.getCollection(collectionPath(collection));
	}
	
	MongoCollection getCollection(ModelType)() {
		return getCollection(containerName!ModelType);
	}
	
	string collectionPath(string name) {
		return _databaseName ~ "." ~ name;
	}
	
	void ensureIndex(M)(int[string] fieldOrders, IndexFlags flags = cast(IndexFlags)0) {
		getCollection!M.ensureIndex(fieldOrders, flags);
	}
	
	Bson dropCollection(string collection) {
		auto command = Bson.emptyObject;
		command.drop = collection;
		return database.runCommand(command);
	}
	
	/// Executes the given query within the container for the model and calls the delegate for each match
	void query(ModelType, Q)(Q query, scope void delegate(Bson model) pred = null, uint limit = 0) {
		import std.array;
		import std.algorithm;
		
		auto collection = getCollection!ModelType;
		query._type = ModelType.stringof;
		
		auto cursor = collection.find(query);
		if (limit) cursor.limit(limit);
		
		while (!cursor.empty) {
			auto bsonModel = cursor.front;
			if (pred) pred(bsonModel);
			cursor.popFront;
		}
	}
	
	/// Returns an array of Bson models matching the list of ids given
	Bson[] find(ModelType, string key = "_id", IdType)(IdType[] ids ...) {
		import std.array;
		import std.algorithm;
		
		Bson[] models;
		auto q = serializeToBson([key: ["$in": ids]]);
		
		query!ModelType(q, 
			(model) {
				// Add to cache here
				models ~= model;
			}
			);
		
		return models;
	}
	
	/// Returns a single Bson model matching the given id
	Bson find(ModelType, string key = "_id", IdType)(IdType id) {
		import std.conv;
		
		auto models = find!(ModelType, key, IdType)([id]);
		if (models.length) return models[0];
		return Bson(null);
	}
	
	/// Executes the the given query on the models container and calls the delegate with the deserialised model for each match.
	void queryModel(ModelType : ModelInterface, S, Q)(S store, Q query, scope void delegate(ModelType model) pred = null, uint limit = 0) {
		import std.array;
		import std.algorithm;
		
		this.find!ModelType(query, 
			(bsonModel) {
				ModelType model = store.findInStore(bsonModel._id.to!string);
				auto injectInStore = model ? false : true;
				deserializeBson(model, bsonModel);
				if (injectInStore) store.inject(model);
				if (pred) pred(model);
			}
			, limit);
	}
	
	/// Returns an array of deserialized models matching the list of ids given
	ModelType[] findModel(ModelType, string key = "", IdType)(const IdType[] ids ...) {
		import std.array;
		import std.algorithm;
		
		ModelType[] models;
		
		auto collection = getCollection!ModelType;
		
		auto result = collection.find([(key.length ? key : "_id"): ["$in": ids]]);
		
		while (!result.empty) {
			ModelType model;
			auto bsonModel = result.front;
			deserializeBson(model, bsonModel);
			models ~= model;
			result.popFront;
		}
		return models;
	}
	
	/// Returns a single deserialized model matching the given id
	ModelType findModel(ModelType, string key = "", IdType)(const IdType id) {
		import std.conv;

		auto models = findModel!(ModelType, key, IdType)([id]);
		if (models.length) return models[0];
		static if(is(ModelType == class)) return null;
		else throw new NoModelForIdException("Could not find model with id " ~ to!string(id) ~ " in " ~ containerName!ModelType);
	}
	
	bool save(M)(ref M model) {
		auto collection = getCollection!M;
		
		Bson bsonModel;
		
		ensureEmbeddedMongoIds(model);
		if(model.isNew) {
			model.ensureId();
			bsonModel = serializeToBson(model);
			logDebugV("Inserting into collection %s: %s", containerName!M, bsonModel.toString);
			collection.insert(model);
		} else {
			bsonModel = serializeToBson(model);
			logDebugV("Upserting %s into collection %s: %s", model.id.toString, containerName!M, bsonModel.toString);
			collection.update(["_id": model.id], bsonModel, UpdateFlags.Upsert);
		}
		
		return true;
	}
	
	bool remove(M)(ref M model) {
		auto collection = getCollection(modelMeta!M.containerName);
		collection.remove(["_id": model.id]);
		return true;
	}
}
