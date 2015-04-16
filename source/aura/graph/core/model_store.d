module aura.persist.core.model_store;

import aura.persist.core.model;
version (unittest) {
	import std.stdio;
	import colorize;
}

alias PersistIndexKeyDelegate = string function(PersistModelInterface);

struct PersistIndexMeta {
	string name;
	PersistIndexKeyDelegate getKey;
}

/// Stores and indexes PersistModels. Each instance is should only hold a single model type
class PersistModelStore {
	@property bool empty() const {
		if ("" !in _store) return true;
		if (_store[""].length == 0) return true;
		return false;
	}
	
	void addIndex(string key, PersistIndexKeyDelegate getKey) {
		_indexMeta[key] = PersistIndexMeta(key, getKey);
	}
	
	void addIndex(M, string attribute)() {
		addIndex(attribute, (model) => __traits(getMember, cast(M)model, attribute));
	}
	
	void inject(PersistModelInterface model) {
		assert(model.persistState.validId, "Attempted to inject a model into the store that does not have an Id");
		version (unittest) { writefln("Injecting '%s'", model.persistState.id.color(fg.yellow)); }
		_store[""][model.persistState.id] = model;
		
		foreach (key, meta; _indexMeta) {
			version (unittest) { writefln("Injecting '%s' into index '%s'", meta.getKey(model).color(fg.yellow), key); }
			_store[key][meta.getKey(model)] = model;
		}
	}
	
	void clear() {
		if (empty) return;
		foreach(id, model; _store[""])
			remove(model);
	}
	
	void remove(PersistModelInterface model) {
		if (empty) return;
		if (!model.persistState.validId) return;
		
		auto id = model.persistState.id;
		_store[""].remove(id);
		foreach (key, meta; _indexMeta) {
			_store[key].remove(meta.getKey(model));
		}
	}
	
	PersistModelInterface[string] opIndex(string key) {
		return _store[key];
	}
	
	// TODO: Allow any id type as long as it can be converted to a string
	M get(M, V)(string key, V value) {
		string id;
		static if (is(V == string)) 
			id = value;
		else 
			id = value.to!string;
		
		PersistModelInterface model;
		version (unittest) { writefln("Getting '%s' from index '%s'", id.color(fg.light_blue), key); }
		assert(key == "" || key in _indexMeta, "Attempted to look up unregistered key '" ~ key ~ "` in store for model '" ~ M.stringof ~ "'");
		if (key !in _store) return cast(M)model; // Return if nothing has been put into the index yet
		
		auto modelStore = _store[key];
		if (id in modelStore) {
			version (unittest) { writefln("Found".color(fg.light_green)); }
			version (unittest) { writefln("%s".color(fg.light_magenta), modelStore); }
			model = modelStore[id];
		}
		return cast(M)model;
	}
	
	M get(M, V)(V value) {
		return get!M("", value);
	}
	
private:
	PersistIndexMeta[string] _indexMeta;
	PersistModelInterface[string][string] _store; // Index, Id
}

version (unittest) {
	unittest {
		class Person : PersistModel {
			string firstName;
			string surname;
			string companyReference;
		}
		
		auto modelStore = new PersistModelStore;
		modelStore.addIndex!(Person, "firstName");
		assert(modelStore.empty);
		
		Person person = new Person();
		person.persistState.id = "1";
		person.firstName = "George";
		
		modelStore.inject(person);
		assert(!modelStore.empty);
		
		assert(!modelStore.get!Person("2"));
		assert(modelStore.get!Person("1"));
		
		auto personClone = modelStore.get!Person("1");
		assert(personClone == person);
		
		assert(!modelStore.get!Person("firstName", "Fred"));
		assert(modelStore.get!Person("firstName", "George") == person);
		
		modelStore.clear();
		assert(modelStore.empty);
	}
}

