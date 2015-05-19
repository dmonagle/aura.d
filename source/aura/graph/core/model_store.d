module aura.graph.core.model_store;

import aura.graph.core.model;

import std.algorithm;

version (unittest) {
	import std.stdio;
	import colorize;
}


/// Stores and indexes GraphModels. Each instance is should only hold a single model type
class GraphModelStore {
	alias GraphIndexKeyDelegate= string function(GraphStateInterface);

	struct GraphIndexMeta {
		string name;
		GraphIndexKeyDelegate getKey;
	}
	

	@property bool empty() const {
		if ("" !in _store) return true;
		if (_store[""].length == 0) return true;
		return false;
	}
	
	void addIndex(string key, GraphIndexKeyDelegate getKey) {
		_indexMeta[key] = GraphIndexMeta(key, getKey);
	}
	
	void addIndex(M : GraphStateInterface, string attribute)() {
		addIndex(attribute, (model) => __traits(getMember, cast(M)model, attribute));
	}

	bool hasIndex(string key) const {
		if (key in _indexMeta) return true;
		return false;
	}
	
	void inject(GraphStateInterface model) {
		assert(model.graphState.validId, "Attempted to inject a model of type '" ~ model.graphType ~ "' into the store that does not have an Id");
		version (unittest) { writefln("Injecting '%s'", model.graphState.id.color(fg.yellow)); }
		_store[""][model.graphState.id] = model;
		
		foreach (index, meta; _indexMeta) {
			version (unittest) { writefln("Injecting '%s' into index '%s'", meta.getKey(model).color(fg.yellow), index); }
			auto key = meta.getKey(model); 
			//assert(key.length, "Indexed value is empty when trying to index '" ~ index ~ "' for model '" ~ model.graphType ~ "'");
			if (key.length) {
				_store[index][key] = model;
			}
		}
	}
	
	void clear() {
		_store = (GraphStateInterface[string][string]).init;
	}
	
	void remove(GraphStateInterface model) {
		if (empty) return;
		if (!model.graphState.validId) return;
		
		auto id = model.graphState.id;
		_store[""].remove(id);
		foreach (key, meta; _indexMeta) {
			_store[key].remove(meta.getKey(model));
		}
	}

	GraphStateInterface[string] opIndex(string key) {
		return _store[key];
	}
	
	GraphStateInterface retrieve(string key, string id) {
		GraphStateInterface model;
		version (unittest) { writefln("Getting '%s' from index '%s'", id.color(fg.light_blue), key); }
		assert(key == "" || key in _indexMeta, "Attempted to look up unregistered key '" ~ key ~ "` in ModelStore");
		if (key !in _store) return model; // Return if nothing has been put into the index yet
		
		auto modelStore = _store[key];
		if (id in modelStore) {
			version (unittest) { writefln("Found".color(fg.light_green)); }
			version (unittest) { writefln("%s".color(fg.light_magenta), modelStore); }
			model = modelStore[id];
		}
		return model;
	}
	
	M get(M  : GraphStateInterface, V)(string key, V value) {
		string id;
		static if (is(V == string)) 
			id = value;
		else 
			id = value.to!string;

		return cast(M)retrieve(key, id);
	}
	
	M get(M : GraphStateInterface, V)(V value) {
		return get!M("", value);
	}

	auto pendingSync() {
		GraphStateInterface[] records;

		if (!empty) {
			foreach(id, record; _store[""]) {
				if (record.graphState.needsSync) records ~= record;
			}
		}

		return records;
	}
	
private:
	GraphIndexMeta[string] _indexMeta;
	GraphStateInterface[string][string] _store; // Index, Id
}

version (unittest) {
	unittest {
		class Graph {
		}

		class Person : GraphModel!Person {
			string firstName;
			string surname;
			string companyReference;
		}
		
		auto modelStore = new GraphModelStore;
		modelStore.addIndex!(Person, "firstName");
		assert(modelStore.empty);
		
		Person person = new Person();
		person.graphState.id = "1";
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

		import aura.data.json;
		writeln(person.serializeToJson.toPrettyString.color(fg.green));
	}
}

