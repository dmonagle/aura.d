/**
	* 
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.mongodb.adapter;

import aura.graph.core;
import aura.graph.mongodb.bson;
import aura.data.bson;

import vibe.db.mongo.mongo;
import vibe.core.log;


class GraphMongoAdapter(Models ...) : GraphAdapter!Models {
	static @property ref string databaseName() { return _databaseName; }
	static @property ref string url() { return _url; }

	/// Returns the underlying MongoClient 
	static @property MongoClient client() {
		if (!_connected) {
			_client = connectMongoDB(_url);
			_connected = true;
		}
		return _client;
	}

	/// Returns the underlying MongoDatabase object
	static @property MongoDatabase database() {
		assert(databaseName.length, "Property databaseName must not be empty");
		return client.getDatabase(databaseName);
	}

	static MongoCollection getCollection(string modelType) {
		return client.getCollection(collectionPath(modelType));
	}
	
	static MongoCollection getCollection(ModelType)() {
		return getCollection(ModelType.stringof);
	}

	static Bson dropCollection(string collection) {
		auto command = Bson.emptyObject;
		command.drop = collection;
		return database.runCommand(command);
	}
	
	static Bson dropCollection(M : GraphModelInterface)() {
		auto name = containerNameFor(M.stringof);
		return dropCollection(name);
	}
	
	static string collectionPath(string modelType) {
		return _databaseName ~ "." ~ containerNameFor(modelType);
	}
	
	static void ensureIndex(M)(int[string] fieldOrders, IndexFlags flags = cast(IndexFlags)0) {
		getCollection!M.ensureIndex(fieldOrders, flags);
	}

	override bool sync() {
		foreach(M; Models) {
			foreach(m; graph.modelStore!M) {
				auto model = cast(M)m;

				if (model.graphDeleted) {
					graph.emitModelWillDelete(model);
					if (_delete(model)) graph.emitModelDidDelete(model);
				}
				else {
					graph.emitModelWillSave(model);
					if (_save(model)) graph.emitModelDidSave(model);
				}
			}
		}
		return true;
	}

	/// Deletes the model from the databaase
	static bool _delete(M : GraphModelInterface)(M model) {
		if (model.graphPersisted) {
			auto collection = getCollection!M;
			logDebugV("GraphMongoAdapter: Removing from collection %s: %s", collection.name, model._id);
			collection.remove(["_id": model._id]);
		}
		return true;
	}

	/// Saves the model to the database using an insert or upsert, returns false if saving is not necessary
	static bool _save(M : GraphModelInterface)(M model) {
		auto collection = getCollection!M;
		bool result = true; 

		// If we are going to allow embedded ids, this is where we ensure them?
		if(!model.graphPersisted) {
			model.ensureId;
			Bson bsonModel = model.serializeToBson;
			logDebugV("GraphMongoAdapter: Inserting into collection %s: %s", collection.name, bsonModel.toString);
			collection.insert(bsonModel);
		} else {
			import std.stdio;
			import colorize;

			if (model.graphSynced) { // The model hasn't manually been touched so update with the diff method
				auto diff = model.diffFromSnapshot;
				if (diff.empty) {
					result = false; // Nothing to save
				}
				else { // Only call $set if there are differences from the snapshot
					Bson bsonModel = Bson.emptyObject;
					bsonModel["$set"] = diff.toBson;
					logDebugV("Upserting %s differences into collection %s: %s", model._id, collection.name, bsonModel.toString);
					collection.update(["_id": model._id], bsonModel, UpdateFlags.Upsert);
				}
			}
			else {
				Bson bsonModel = model.serializeToBson;
				logDebugV("Upserting %s into collection %s: %s", model._id, collection.name, bsonModel.toString);
				collection.update(["_id": model._id], bsonModel, UpdateFlags.Upsert);
			}
		}
		model.graphPersisted = true;
		model.graphUntouch;
		model.takeSnapshot;

		return result;
	}

private:
	static {
		MongoClient _client;
		string _url;
		string _databaseName;
		bool _connected;
	}
}