module aura.persistence.core.adapter;

import aura.persistence.core.model;
import aura.util.string_transforms;
import aura.util.inflections.en;

import vibe.core.log;

import std.algorithm;
import std.typetuple;

interface PersistenceAdapterInterface {
}

/// The mandatory functions for working with a store are as follows:
/// ModelType[] storeFindMany(ModelType, string key = "", StoreType, IdType)(StoreType store, const IdType[] ids ...)
/// ModelType storeFindOne(ModelType, string key = "", StoreType, IdType)(StoreType store, const IdType id)
/// void storeQuery(ModelType : ModelInterface, S, Q)(S store, Q query, scope void delegate(ModelType) pred = null, uint limit = 0)
class PersistenceAdapter(M ...) : PersistenceAdapterInterface {
	alias ModelTypes = TypeTuple!M;

	this() {
		_modelContainers.length = ModelTypes.length;
	}

	@property ref string databaseName() {
		return _databaseName;
	}

	template modelIsRegistered(M) {
		enum modelIsRegistered = staticIndexOf!(M, ModelTypes) != -1;
	}

	@property string containerName(M)() {
		alias index = staticIndexOf!(M, ModelTypes);
		static assert(index != -1, "Attempted to look up the container of a model that is not part of an adapter: " ~ M.stringof);
		string value = _modelContainers[index];
		if (!value.length) {
			value = (M.stringof).snakeCase.pluralize;
			_modelContainers[index] = value;
		}
		return value;
	}
	
	@property void containerName(M)(const string name) {
		alias index = staticIndexOf!(M, ModelTypes);
		static assert(index != -1, "Attempted to set the container of a model that is not part of the adapter: " ~ M.stringof);
		_modelContainers[index] = name;
	}
	
	bool saveToContainer(M : ModelInterface)(string container, const M model) {
		return false;
	}

protected:
	string _databaseName;
	string[] _modelContainers;
}


