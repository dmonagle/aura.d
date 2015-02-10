module aura.persistence.mongodb.adapter;

import aura.persistence.core;
import aura.persistence.mongodb.model;

public import vibe.db.mongo.mongo;
public import vibe.data.bson;
public import vibe.core.log;

public import std.datetime;

class MongoAdapter(M ...) : PersistenceAdapter!M {

	/// Returns true if the MongoClient is connected
	@property bool connected() const { return _connected; }
	
	/// Returns the underlying MongoClient 
	@property MongoClient client() {
		if (!connected) {
			_client = connectMongoDB(_url);
			_connected = true;
		}
		return _client;
	}

	/// Used to get or set the URL to connect to the mongo database
	@property ref string url() { return _url; }

	/// Returns the underlying MongoDatabase object
	@property MongoDatabase database() {
		assert(_databaseName.length, "Property databaseName must not be empty");
		return client.getDatabase(_databaseName);
	}

	/// Sets the name of the database
	@property void database(string name) {
		_databaseName = name;
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

	/// Inserts or updates the model into the database
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
	
	/// Removes the model from the database
	bool remove(M)(ref M model) {
		auto collection = getCollection(modelMeta!M.containerName);
		collection.remove(["_id": model.id]);
		return true;
	}

	/// Returns a MongoCursor based on the given ModelType and query
	auto queryCursor(ModelType, Q)(Q query) {
		auto bsonQuery = query.serializeToBson;
		auto collection = getCollection!ModelType;
		query._type = ModelType.stringof;
		
		return collection.find(query);
	}

	/// Executes the given query within the container for the model and calls the delegate for each match
	/// passing in the Bson object
	void query(ModelType, Q, S = typeof(null))(Q query, scope void delegate(Bson model) pred = null, uint limit = 0, S sort = null) {
		import std.array;
		import std.algorithm;
		
		auto cursor = queryCursor!ModelType(query);

		if (limit) cursor.limit(limit);
		static if (!is(S == typeof(null)))
			cursor.sort(sort);

		while (!cursor.empty) {
			auto bsonModel = cursor.front;
			if (pred) pred(bsonModel);
			cursor.popFront;
		}
	}

	/// Executes the the given query on the models container and calls the delegate with the deserialised model for each match.
	/// This function will look to update the model in the given store 
	void storeQuery(ModelType : ModelInterface, S, Q)(S store, Q query, scope void delegate(ModelType model) pred = null, uint limit = 0) {
		import std.array;
		import std.algorithm;
		
		this.query!ModelType(query, 
			(bsonModel) {
				ModelType model = store.findInStore!ModelType(bsonModel._id.to!string);
				auto injectInStore = model ? false : true;
				deserializeBson(model, bsonModel);
				if (injectInStore) store.inject(model);
				if (pred) pred(model);
			}
			, limit);
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
	
	/// Returns an array of deserialized models matching the list of ids given
	ModelType[] findMany(ModelType, string key = "", IdType)(const IdType[] ids ...) {
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
	ModelType findOne(ModelType, string key = "", IdType)(const IdType id) {
		import std.conv;

		ModelType model;

		auto collection = getCollection!ModelType;
		auto result = collection.find([(key.length ? key : "_id"): Bson(id)]);
		result.limit(1);

		if (!result.empty) {
			model.deserializeBson(result.front);
			return model;
		}

		static if(is(ModelType == struct))
			throw new NoModelForIdException("Could not find model with id " ~ to!string(id) ~ " in " ~ containerName!ModelType);
		else
			return model;
	}

private:
	MongoClient _client;
	string _url;
	bool _connected;
}
