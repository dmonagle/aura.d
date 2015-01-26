module aura.persistence.core.adapter;

import aura.persistence.core.model;
import aura.util.string_transforms;
import aura.util.inflections.en;

import vibe.core.log;

import std.algorithm;
import std.typetuple;

interface PersistenceAdapterInterface {
}

class PersistenceAdapter(M ...) : PersistenceAdapterInterface {
	alias ModelTypes = TypeTuple!M;

	this() {
		_modelContainers.length = ModelTypes.length;
	}

	@property ref string databaseName() {
		return _databaseName;
	}

	@property string containerName(M)() {
		alias index = staticIndexOf!(M, ModelTypes);
		assert(index != -1, "Attempted to look up the container of a model that is not part of the adapter: " ~ M.stringof);
		string value = _modelContainers[index];
		if (!value.length) {
			value = (M.stringof).snakeCase.pluralize;
			_modelContainers[index] = value;
		}
		return value;
	}
	
	@property void containerName(M)(const string name) {
		alias index = staticIndexOf!(M, ModelTypes);
		assert(index != -1, "Attempted to set the container of a model that is not part of the adapter: " ~ M.stringof);
		_modelContainers[index] = name;
	}
	
	bool saveToContainer(M : ModelInterface)(string container, const M model) {
		return false;
	}

protected:
	string _databaseName;
	string[] _modelContainers;
}


