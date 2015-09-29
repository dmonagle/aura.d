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
	BsonObjectID _id;

	void enforceId() {
		if (!_id.valid) _id = BsonObjectID.generate;
	}
}

