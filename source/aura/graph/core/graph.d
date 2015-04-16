module aura.graph.core.graph;

import aura.graph.core.model;
import aura.graph.core.model_store;
import aura.graph.core.adapter;
import aura.graph.core.embedded;

import vibe.core.log;

import std.typetuple;
import std.traits;
import std.algorithm;

class Graph(A ...) {
	alias AdapterTypes = TypeTuple!A;
	alias ModelTypes = NoDuplicates!(staticMap!(adapterModels, AdapterTypes));

	alias ModelInterface = GraphModelInterface!(Graph!(A));
	alias Model = GraphModel!(Graph!A);

	alias AdapterLookupDelegate = ModelInterface delegate(string modelType, string attribute, string value);

	static template adapterModels(A) {
		alias adapterModels = A.ModelTypes;
	}

	// Make sure that each adapter is only added once
	static assert (AdapterTypes.length == NoDuplicates!(AdapterTypes).length, "Store can not have more than one of the same type of adapter");
	
	/// Returns the adapters types that have the model M registered
	template adapterTypesFor(M) {
		alias adapterTypesFor = Filter!(RegisteredModel!M.inAdapter, AdapterTypes);
	}
	
	/// Returns the first adapter type that has the model M registered
	template adapterTypeFor(M) {
		alias adapters = adapterTypesFor!M;
		static assert(adapters.length, "No adapter found in store for model " ~ M.stringof);
		alias adapterTypeFor = adapters[0];
	}
	
	/// Returns the first registered adapter for the give model (M)
	template adapterFor(M) {
		alias adapterFor = adapter!(adapterTypeFor!M);
	}

	// Returns a lazy initialized adapter at the given index, cast into A. 
	static A adapter(A)() {
		auto index = staticIndexOf!(A, AdapterTypes);
		auto a = _adapters[index];
		if (a) return cast(A)a;
		a = new A();
		_adapters[index] = a;
		return cast(A)a;
	}

	void addIndex(M)(string key, GraphIndexKeyDelegate getKey) {
		storeForModel!M.addIndex(key, getKey);
	}

	void addIndex(M : ModelInterface, string attribute)() {
		modelStore!M.addIndex!(M, attribute);
	}

	bool hasIndex(M : ModelInterface)(string key) {
		return modelStore!M.hasIndex(key);
	}

	/// Ensures that this is set to be the graphInstance on the model and all embedded models
	void ensureGraphReferences(M : ModelInterface)(M model) {
		model.graphInstance = this;
		eachEmbeddedGraph!((model, parent) {
				model.graphInstance = this;
				model.graphParent = parent;
			})(model);
	}

	void inject(M : ModelInterface)(M model) {
		if (!model.graphState.validId) {
			if (auto adapter = adapterFor!M) {
				adapter.ensureId(model);
			}
		}
		ensureGraphReferences(model);
		modelStore!M.inject(model);
	}

	void clear() {
		foreach(store; _modelStores) {
			if (store) {
				store.clear();
			}
		}
	}

	/// Returns true if there are models in the graph that need syncing.
	@property ulong unsyncedCount() {
		ulong result;

		foreach(index, M; ModelTypes) {
			auto store = _modelStores[index];
			if (store) {
				result += store.pendingSync.length;
			}
		}

		return result;
	}

	/// Returns true if there are models in the graph that need syncing.
	@property bool needsSync() {
		foreach(index, M; ModelTypes) {
			auto store = _modelStores[index];
			if (store) {
				if (store.pendingSync.length) return true;
			}
		}
		return false;
	}

	M[] query(M : ModelInterface)(M[] delegate(Graph!A) queryDelegate) {
		auto models = queryDelegate(this);

		M[] results;

		foreach(model; models) {
			if (model.validGraphId) {
				logDebug("Looking up model with id: %s", model.graphState.id);
				if (auto alreadyInStore = find!M(model.graphState.id)) 
					results ~= alreadyInStore;
				else {
					inject(model);
					results ~= model;
				}
			}
			else {
				assert(false, "Query returned a model without a valid graphId");
			}
		}
		return results;
	}

	M find(M : ModelInterface, string key = "", V)(V id) {
		static if (is(V == string)) {
			string idString = id;
		}
		else {
			string idString = id.to!string;
		}

		auto model = modelStore!M.get!M(key, idString);

		// If the model wasn't in the store, we can try the adapter
		if (!model) {
			if (auto adapter = adapterFor!M) {
				static if (key == "")
					model = adapter.find!M(idString);
				else
					model = adapter.find!M(key, idString);

				if (model) inject(model);
			}
			else {
				assert("No adapter found for " ~ M.stringof);
			}
		}

		return model;
	}

	bool sync(M)(M model) {
		import std.stdio;
		import colorize;

		bool result = true;

		if (model.graphState.deleted) {
			logDebugV("Store is going to delete %s: %s".color(fg.light_red), M.stringof, model.graphState.id);
			eachAdapterFor!(Graph!A, M, (a) { if (!a.remove(model)) result = false;} );

			if (result) {
				modelStore!M.remove(model);
				model.graphState.dirty = false;
				model.graphState.persisted = false;
			}
		}
		else {
			logDebugV("Store is going to save %s: %s".color(fg.light_green), M.stringof, model.graphState.id);
			eachAdapterFor!(Graph!A, M, (a) { if (!a.save(model)) result = false;} );

			if (result) {
				model.graphState.dirty = false;
				model.graphState.persisted = true;
			}
		}

		return result;
	}

	bool sync() {
		bool result = true;

		foreach(index, M; ModelTypes) {
			auto store = _modelStores[index];
			if (store) {
				if (store.pendingSync.length) {
					foreach(record; store.pendingSync) {
						auto model = cast(M)record;
						sync(model);
					}
				}
			}
		}

		return result;
	}

private:
	static GraphAdapterInterface[AdapterTypes.length] _adapters;
	GraphModelStore[ModelTypes.length] _modelStores;

	// Returns the store object for the given model
	@property GraphModelStore modelStore(M)() {
		auto i = staticIndexOf!(M, ModelTypes);
		assert(i != -1, "Attempted to look up store for unregistered model: " ~ M.stringof);
		auto ms = _modelStores[i];
		if (ms) return ms;
		ms = new GraphModelStore;
		_modelStores[i] = ms;
		return ms;
	}

	struct RegisteredModel(M : ModelInterface) {
		// Precompilable function that Returns true if the given model is resgistered against the given adapter
		static template inAdapter(A) {
			immutable bool inAdapter = staticIndexOf!(M, A.ModelTypes) != -1;
		}
	}
}

// Goes through each adapter on the graph (G) and calls the delegate if the adapter has the specified model (M) registered
void eachAdapterFor(G, M, alias adapterDelegate)() {
	foreach(AdapterType; G.AdapterTypes) {
		auto a = G.adapter!AdapterType;
		static if (a.modelIsRegistered!M) {
			adapterDelegate(a);
		}
	}
}

