/**
	* 
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.mongodb.model;

import aura.graph.core.model;
import vibe.data.bson;

class GraphMongoModel : GraphModel {
	override @optional @property string graphId() const { return _id.toString; }
	override @ignore @optional @property void graphId(string newId) { _id = BsonObjectID.fromString(newId); }

	@property BsonObjectID _id() const { return _modelId; }
	@property void _id(BsonObjectID value) { 
		_modelId = value;
		graphPersisted = _modelId.valid;
	}

	void ensureId() {
		if (!_modelId.valid) _modelId = BsonObjectID.generate;
	}

	/// Sets the persisted property. This will ensure the Id
	override @ignore @optional @property void graphPersisted(bool value) {
		super.graphPersisted(value);
		if (value) {
			ensureId;
		}
	}

	override @property bool graphPersisted() const {
		if (!_modelId.valid) return false; // Can't be persisted if there is no Id
		return super.graphPersisted;
	}

private:
	BsonObjectID _modelId;
}


unittest {
	auto m = new GraphMongoModel;

	assert(!m._modelId.valid, "A new model should not have a valid _id");
	assert(!m.graphPersisted, "A model without a valid _id is not persisted");
	m._id = BsonObjectID.generate;
	assert(m.graphPersisted, "The model should appear as persisted as it has a valid _id");
	m.graphPersisted = false;
	assert(!m.graphPersisted, "Should be able to be forced as unpersisted");
	assert(m._modelId.valid, "The _id should be intact");
}

unittest {
	auto serialized = parseJsonString(`{"_id": "562da5d4d237a37031000001"}`);
	GraphMongoModel model;
	model.deserializeJson(serialized);
	assert(model.graphPersisted); // As model was deserialized from JSON that contained an _id, it is assumed it has been persisted
}