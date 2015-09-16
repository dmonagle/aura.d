module aura.graph.core.adapter;

import aura.graph.core.model;
import vibe.data.bson;

import std.string;
import std.typetuple;

interface GraphAdapterInterface {

}

class GraphAdapter(M ...) : GraphAdapterInterface {
	alias ModelTypes = TypeTuple!M;

	template modelIsRegistered(M) {
		enum modelIsRegistered = staticIndexOf!(M, ModelTypes) != -1;
	}
	
	struct ContainerMeta {
		string name;
	}

	@property ref string databaseName() { return _databaseName; }

	void ensureId(GraphStateInterface model) {
		if (!model.graphState.validId) model.graphState.id = BsonObjectID.generate.toString;
	}

	@property ref ContainerMeta containerMeta(M : GraphStateInterface)() {
		alias index = staticIndexOf!(M, ModelTypes);
		static assert(index != -1, "Attempted to look up the container of a model that is not part of an adapter: " ~ M.stringof);
		return _containerMeta[index];
	}

	@property string containerName(M)() {
		import aura.util.inflections.en;
		import aura.util.string_transforms;

		auto meta = containerMeta!M;
		if (!meta.name) {
			meta.name = (M.stringof).snakeCase.pluralize;
		}
		return meta.name;
	}
	
	@property void containerName(M)(string name) {
		auto meta = containerMeta!M;
		meta.name = name;
	}

protected:
	string _databaseName;
	ContainerMeta[ModelTypes.length] _containerMeta;
}
