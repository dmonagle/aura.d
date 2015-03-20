module aura.persistence.core.modelCache;

import aura.persistence.core.model;

import std.datetime;

version (unittest) {
	import std.stdio;
	import colorize;
}

/// Caches and indexes model references with ability to expire
class ModelCache {
	this() {
		_storeLife = 3.seconds;
	}
	
	struct IndexMeta {
		string function(ModelInterface) getKey;
	}
	
	void addIndex(string key)(string function(ModelInterface) getKey) {
		_indexMeta[key] = IndexMeta(getKey);
	}
	
	void addIndex(M, string attribute)() {
		addIndex!attribute((model) => __traits(getMember, cast(M)model, attribute));
	}
	
	void inject(ModelInterface m) {
		version (unittest) { writefln("Injecting '%s'", m.persistenceId.color(fg.yellow)); }
		_store[""][m.persistenceId] = m;
		touch(m);
		foreach (key, meta; _indexMeta) {
			version (unittest) { writefln("Injecting '%s' into index '%s'", meta.getKey(m).color(fg.yellow), key); }
			_store[key][meta.getKey(m)] = m;
		}
	}
	
	void clean() {
		foreach(id, model; _store[""])
			if (hasExpired(model)) remove(model);
	}
	
	void remove(ModelInterface m) {
		_store[""].remove(m.persistenceId);
		_expiryTime.remove(m.persistenceId);
		foreach (key, meta; _indexMeta) {
			_store[key].remove(meta.getKey(m));
		}
	}
	
	void touch(ModelInterface m) {
		version (unittest) { writefln("Touching '%s'", m.persistenceId.color(fg.cyan)); }
		_expiryTime[m.persistenceId] = Clock.currTime + _storeLife;
	}
	
	bool hasExpired(ModelInterface m) {
		return hasExpired(m.persistenceId);
	}
	
	bool hasExpired(string persistenceId) {
		version (unittest) { writefln("Checking expiry '%s'", persistenceId.color(fg.light_blue)); }
		return Clock.currTime >= _expiryTime[persistenceId];
	}
	
	ModelInterface[string] opIndex(string key) {
		return _store[key];
	}
	
	void add(string key, string id, ModelInterface model) {
	}
	
	// TODO: Allow any id type as long as it can be converted to a string
	ModelInterface get(M)(string key, string id) {
		ModelInterface model;
		version (unittest) { writefln("Getting '%s' from index '%s'", id.color(fg.light_blue), key); }
		assert(key == "" || key in _indexMeta, "Attempted to look up unregistered key '" ~ key ~ "` in store for model '" ~ M.stringof ~ "'");
		if (key !in _store) return model; // Return if nothing has been put into the index yet
		
		auto models = _store[key];
		if (id in models) {
			version (unittest) { writefln("Found".color(fg.light_green)); }
			version (unittest) { writefln("%s".color(fg.light_magenta), models); }
			model = models[id];
			if (hasExpired(model.persistenceId)) {
				remove(model);
				model = ModelInterface.init;
			}
		}
		return cast(M)model;
	}
	
	ModelInterface get(M)(string id) {
		return get!M("", id);
	}
	
private:
	Duration _storeLife;
	IndexMeta[string] _indexMeta;
	SysTime[string] _expiryTime;
	ModelInterface[string][string] _store;
}

version (unittest) {
	unittest {
		class TestModelBase : ModelInterface {
			mixin PersistenceTypeProperty;
			@ignore @property string persistenceId() const { return _id; }
			@property void persistenceId(string id) { _id = id; }
			void ensureId() {}
			@ignore @property bool isNew() const { return false; }
			
			string _id;
		}
		
		class Person : TestModelBase {
			string firstName;
			string surname;
			string companyReference;
		}
		
		auto modelStore = new ModelCache;
		modelStore.addIndex!(Person, "firstName");
		
		Person person = new Person();
		person._id = "1";
		person.firstName = "David";
		
		modelStore.inject(person);
		
		assert(!modelStore.get!Person("2"));
		assert(modelStore.get!Person("1"));
		
		auto personClone = modelStore.get!Person("1");
		assert(personClone == person);
		
		assert(!modelStore.get!Person("firstName", "Fred"));
		assert(modelStore.get!Person("firstName", "David") == person);
	}
}

