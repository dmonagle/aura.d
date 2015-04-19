module aura.graph.mongodb.model;

import aura.graph.core.model;
import aura.graph.mongodb.adapter;

import aura.util.null_bool;

public import aura.data.bson;
public import std.datetime;

class GraphMongoModel(GraphType) : GraphModel!GraphType {
	@optional {
		@property BsonObjectID _id() const {
			BsonObjectID returnId;
			if (graphState.id.length == 24) returnId = BsonObjectID.fromString(graphState.id);
			return returnId;
		}

		@property void _id(BsonObjectID newId) {
			graphState.id = newId.to!string;
		}

		@property const string _type() { return graphType; }
		// Dummy setter so that _type will be serialized
		@property void _type(string graphType) {}
	}
	
	@property Nullable!SysTime createdAt() {
		Nullable!SysTime returnTime;
		auto id = _id;
		if (id.valid) returnTime = id.timeStamp;
		return returnTime;
	}
}

