/**
	* 
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.mongodb.adapter;

import aura.graph.core;
import vibe.db.mongo.mongo;

class GraphMongoAdapter(Models ...) : GraphAdapter!Models {
	@property ref string databaseName() { return _databaseName; }
	
	/// Returns the underlying MongoClient 
	@property MongoClient client() {
		if (!_connected) {
			_client = connectMongoDB(_url);
			_connected = true;
		}
		return _client;
	}
	
	MongoCollection getCollection(string modelType) {
		return client.getCollection(collectionPath(modelType));
	}
	
	MongoCollection getCollection(ModelType)() {
		return getCollection(ModelType.stringof);
	}
	
	string collectionPath(string modelType) {
		return _databaseName ~ "." ~ containerNameFor(modelType);
	}
	
	void ensureIndex(M)(int[string] fieldOrders, IndexFlags flags = cast(IndexFlags)0) {
		getCollection!M.ensureIndex(fieldOrders, flags);
	}

private:
	MongoClient _client;
	string _url;
	string _databaseName;
	bool _connected;
}