module aura.graph.mongodb.adapter;

public import aura.data.bson;

import aura.graph.core.model;
import aura.graph.core.adapter;

import vibe.db.mongo.mongo;
import vibe.core.log;

import std.typecons;

class GraphMongoAdapter(M ...) : GraphAdapter!(M) {
	static Bson serialize(M : GraphStateInterface)(const M model) {
		auto bsonModel = model.serializeToBson;
		if (model.graphState.validId) bsonModel["_id"] = BsonObjectID.fromString(model.graphState.id);
		
		return bsonModel;
	}
	
	static M deserialize(M : GraphStateInterface)(Bson bsonModel) {
		M model;
		model.deserializeBson(bsonModel);
		BsonObjectID modelId;
		modelId.deserializeBson(bsonModel["_id"]);
		model.graphState.id = modelId.to!string;
		if (modelId.valid) model.graphState.persisted = true;
		return model;
	}
	
	/// Iterates over a cursor and calls the given delegate with the deserialized model type
	static void eachResult(ModelType, C)(C cursor, void delegate(ModelType) resultDelegate) {
		while (!cursor.empty) {
			ModelType model;
			auto bsonModel = cursor.front;
			model = deserialize!ModelType(bsonModel);
			resultDelegate(model);
			cursor.popFront;
		}
	}
	
	override void ensureId(GraphStateInterface model) {
		if (!model.graphState.validId) model.graphState.id = BsonObjectID.generate.toString;
	}
	
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
		static Nullable!MongoDatabase _database;
		assert(databaseName.length, "Property databaseName must not be empty");
		if (_database.isNull) _database = client.getDatabase(databaseName);
		return _database;
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

	Bson dropCollection(M : GraphStateInterface)() {
		auto name = containerName!M;
		return dropCollection(name);
	}

	/// Returns a MongoCursor based on the given ModelType and query
	auto queryCursor(ModelType, Q)(Q query) {
		auto collection = getCollection!ModelType;
		logDebugV("Querying %s : '%s'", containerName!ModelType, query.to!string);
		return collection.find(query);
	}

	auto queryCursor(ModelType)() {
		return queryCursor!ModelType(Bson.emptyObject);
	}

	/// Deserializes all results of a cursor to the given model
	M[] deserializeCursor(M, C)(C cursor) {
		M[] results;
		
		eachResult!M(cursor, (model) {
				results ~= model;
			});
		
		return results;
	}
	
	/// Removes the model from the database
	bool remove(M : GraphStateInterface)(M model) {
		if (model.validGraphId) {
			auto id = BsonObjectID.fromString(model.graphId);
			auto cName = containerName!M;
			auto collection = getCollection(cName);
			logDebugV("GraphMongoAdapter: Removing from collection %s: %s", cName, model.graphId);
			collection.remove(["_id": id]);
		}
		return true;
	}

	// Saves the model to the database using an insert or upsert
	bool save(M : GraphStateInterface)(M model) {
		auto cName = containerName!M;
		auto collection = getCollection(cName);
		
		Bson bsonModel;

		// If we are going to allow embedded ids, this is where we ensure them?
		if(model.isNew) {
			ensureId(model);
			bsonModel = serialize(model);
			logDebugV("GraphMongoAdapter: Inserting into collection %s: %s", cName, bsonModel.toString);
			collection.insert(bsonModel);
		} else {
			bsonModel = serialize(model);
			logDebugV("Upserting %s into collection %s: %s", model.graphState.id, cName, bsonModel.toString);
			collection.update(["_id": bsonModel["_id"]], bsonModel, UpdateFlags.Upsert);
		}
		
		return true;
	}

	M[] query(M, Q)(Q query, uint limit = 0) {
		M[] results;

		auto cursor = queryCursor!M(query);
		if (limit) cursor.limit = limit;

		return deserializeCursor!M(cursor);
	}

	M[] query(M)(uint limit = 0) {
		return query!M(Bson.emptyObject, limit);
	}

	/// Runs the given query on the adapter and calls the delegate for each deserialized model
	void query(M, Q)(Q query, void delegate(M) modelDelegate, uint limit = 0) {
		auto cursor = queryCursor!M(query);
		if (limit) cursor.limit = limit;
		eachResult!M(cursor, modelDelegate);
	}

	/// Returns all of the models that have the key matchine any of the values
	M[] findMulti(M : GraphStateInterface, V)(string key, V[] values, limit=0) {
		auto cursor = queryCursor!M([key: ["$in": ids]]);
		if (limit) cursor.limit = limit;

		return deserializeCursor!M(cursor);
	}

	M[] findMany(M : GraphStateInterface, V)(string key, V value, uint limit=0) {
		auto cursor = queryCursor!M([key: value]);
		if (limit) cursor.limit = limit;
		auto models = deserializeCursor!M(cursor);

		return models;
	}

	M find(M : GraphStateInterface, V)(string key, V value) {
		if (key == "") key = "_id";
		auto results = findMany!M(key, value, 1);
		if (results.length) return results[0];
		return null;
	}


	M find(M : GraphStateInterface, V)(V id) {
		return find!M("_id", id);
	}
	
	M find(M : GraphStateInterface, V : string)(V id) {
		return find!M(BsonObjectID.fromString(id));
	}

private:
	MongoClient _client;
	string _url;
	bool _connected;
}

