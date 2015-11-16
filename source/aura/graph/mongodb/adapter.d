﻿/**
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


class GraphMongoAdapter(M ...) : GraphAdapter!M {
	alias Models = M;

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

	MongoCollection getCollection(string modelType) {
		return client.getCollection(collectionPath(modelType));
	}
	
	MongoCollection getCollection(ModelType)() {
		return getCollection(ModelType.stringof);
	}

	static Bson dropCollection(string collection) {
		auto command = Bson.emptyObject;
		command.drop = collection;
		return database.runCommand(command);
	}
	
	Bson dropCollection(M : GraphModelInterface)() {
		auto name = containerNameFor(M.stringof);
		return dropCollection(name);
	}
	
	string collectionPath(string modelType) {
		return _databaseName ~ "." ~ containerNameFor(modelType);
	}

	void ensureIndex(M)(scope const(Tuple!(string, int))[] fieldOrders, IndexFlags flags = cast(IndexFlags)0) {
		getCollection!M.ensureIndex(fieldOrders, flags);
	}

	/*
	void ensureIndex(M)(int[string] fieldOrders, IndexFlags flags = cast(IndexFlags)0) {
		getCollection!M.ensureIndex(fieldOrders, flags);
	}
	*/

	/// Sync models in the graph with the database
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
	bool _delete(M : GraphModelInterface)(M model) {
		if (model.graphPersisted) {
			auto collection = getCollection!M;
			logDebugV("GraphMongoAdapter: Removing from collection %s: %s", collection.name, model._id);
			collection.remove(["_id": model._id]);
		}
		return true;
	}

	/// Saves the model to the database using an insert or upsert, returns false if saving is not necessary
	bool _save(M : GraphModelInterface)(M model) {
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

	GraphModelInterface deserialize(string graphType, Bson data) {
		import std.format;

		switch (graphType) {
			foreach(ModelType; Models) {
				case ModelType.stringof:
				ModelType model;
				model.deserializeBson(data);
				return model;
			}
			default: assert(false, format("Type '%s' not supported by adapter", graphType));
		}
	}

	// Query functions

	/// Injects all results from the `cursor` into the graph. 
	M[] injectCursor(M : GraphModelInterface, C)(C cursor, bool snapshot = true, bool merge = false) 
	in {
		assert(graph);
	}
	body {
		M[] _results;

		while (!cursor.empty) {
			M model;
			auto bsonModel = cursor.front;

			auto existingModel = graph.firstModel!(M, (m) => (cast(M)m)._id == bsonModel["_id"].get!BsonObjectID);
			if (existingModel) {
				// Use merge strategy to update the existing model
				if (merge) {
					enforce(false, "This is not implemented yet");
				}
				else {
					_results ~= existingModel;
				}
			}
			else {
				// Create and deserialize a new model
				M newModel = new M();
				newModel.deserializeBson(bsonModel);
				newModel.graphPersisted = true;
				_results ~= graph.inject(newModel, snapshot);
			}
			cursor.popFront;
		}

		return _results;
	}

	override GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit = 0) {
		GraphModelInterface[] results;

		auto cursor = getCollection(graphType).find([key: value.toBson]);
		if (limit) cursor.limit(limit);

		while (!cursor.empty) {
			auto bson = cursor.front;
			auto result = deserialize(graphType, bson);
			result.graphPersisted = true;
			results ~= result;
			cursor.popFront;
		}
		return results;
	}

	/// Runs a query for the given model type and returns the MongoCursor
	auto findCursor(M : GraphModelInterface, T)(T query) {
		return getCollection!M.find(query);
	}

	/// Runs a query for all items in the collection specified by M and returns a MongoCursor
	auto findCursor(M : GraphModelInterface)() {
		return getCollection!M.find();
	}

	/// Find a single model where the key matches the value
	/// The result is injected into the graph. If the result already exists in the graph, it will return the graph value
	M find(M : GraphModelInterface, V)(string key, V value) {
		if (key == "") key = "_id";
		static if (is(V == Bson)) auto searchValue = value;
		else auto searchValue = Bson(value);
		auto cursor = getCollection!M.find([key: value]);
		cursor.limit(1);
		auto results = injectCursor!M(cursor);
		if (results.length) return results[0];
		return null;
	}

	/// ditto
	M find(M : GraphModelInterface, V)(V id) {
		return find!M("_id", id);
	}

private:
	static {
		MongoClient _client;
		string _url;
		string _databaseName;
		bool _connected;
	}
}