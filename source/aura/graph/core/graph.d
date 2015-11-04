/**
	* Graph Storage Class
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.core.graph;

import aura.graph.core.model;
import aura.graph.value;
import aura.graph.core.adapter;
import aura.graph.core.embedded;
import aura.graph.core.events;

import vibe.data.serialization;

import std.algorithm;
import std.array;
import std.traits;

/// Exposes a graphInstance property
interface GraphInstanceInterface {
	@property inout(Graph) graph() inout;
	@property void graph(Graph value);
}


/// Defines a graph property to comply with `GraphInstanceInterface`
mixin template GraphInstanceImplementation() {
	@ignore @property inout(Graph) graph() inout { return _graph; }
	@property void graph(Graph value) { _graph = value; }
	
protected:
	Graph _graph;
}

/// Main storage class for Graph
class Graph {
	mixin GraphModelStoreImplementation;
	
	/// Injects a model into the graph, optionally initiating a snapshot
	M inject(M : GraphModelInterface)(M model, bool snapshot = false) 
	in {
		assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
	}
	body {
		if (model.graph !is this) {
			ensureGraphReferences(model);
			modelStore!(M).addModel(model);
		}
		if (snapshot) model.takeSnapshot;
		return model;
	}
	
	/// Removes the given model from the graph, has no effect if the model is not part of the graph
	void remove(M : GraphModelInterface)(M model)
	in {
		assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
		assert (model.graph is this);
	}
	body {
		modelStore!(M).removeModel(model);
	}
	
	/// Returns the adapter for the graph
	@property GraphAdapterInterface adapter() { return _adapter; }
	/// Sets the adapter for the graph
	@property void adapter(GraphAdapterInterface adapter) { 
		_adapter = adapter; 
		adapter.graph = this;
	}
	
	/// Ensures that `this` is set to be the graph on the model and all embedded models
	void ensureGraphReferences(M : GraphModelInterface)(M model) {
		model.graph = this;
		eachEmbeddedGraph!((model, parent) {
				model.graph = this;
				model.graphParent = parent;
			})(model);
	}

	size_t length() const {
		size_t result;
		foreach(store; _graphModelStores) result += store.length;
		return result;
	}
	
	/// Initiates a sync of the graph with the adapter
	bool sync() {
		if (!_adapter) return false;
		emitGraphWillSync;
		auto result =_adapter.sync;
		emitGraphDidSync;
		return result;
	}
	
	/// Registers the listener with this graph
	void registerGraphEventListener(GraphEventListener listener) {
		if (!_graphEventListeners.canFind(listener)) {
			_graphEventListeners ~= listener;
			listener.graph = this;
		}
	}
	
	/// Registers the listener with this graph
	void unregisterGraphEventListener(GraphEventListener listener) {
		_graphEventListeners = array(_graphEventListeners.filter!((l) => listener !is l));
	}
	
	// Query methods

	/// Used for keys that should be primary within the adapter
	M find(M, string key, V : GraphValue)(V value) {
		auto graphResults = this.filterModels!(M, key)(value);
		if (graphResults.length) return graphResults[0];
		
		if (adapter) {
			auto adapterResults = adapter.graphFind(M.stringof, key, value, 1);
			if (adapterResults.length) return inject!M(cast(M)adapterResults[0]);
		}
		
		return null;
	}

	/// Ditto
	M find(M, string key, V)(V value) {
		return find!(M, key)(GraphValue(value));
	}

	// Emit methods
	void emitGraphWillSync() { foreach(listener; _graphEventListeners) listener.graphWillSync(); }
	void emitModelWillSave(GraphModelInterface model) { foreach(listener; _graphEventListeners) listener.modelWillSave(model); }
	void emitModelDidSave(GraphModelInterface model) { foreach(listener; _graphEventListeners) listener.modelDidSave(model); }
	void emitModelWillDelete(GraphModelInterface model) { foreach(listener; _graphEventListeners) listener.modelWillDelete(model); }
	void emitModelDidDelete(GraphModelInterface model) { foreach(listener; _graphEventListeners) listener.modelDidDelete(model); }
	void emitGraphDidSync() { foreach(listener; _graphEventListeners) listener.graphDidSync(); }
	
private:
	GraphAdapterInterface _adapter;
	GraphEventListener[] _graphEventListeners;
}

/// Returns an array of M from within the graph that match the given predicate
M[] filterModels(M : GraphModelInterface, alias predicate = (m) => true)(Graph graph) {
	auto results = array(graph.modelStore!M.filter!((m) => predicate(cast(M)m)));
	return array(results.map!((m) => cast(M)m));
}

/// Returns an array of M from within the graph that match the given predicate
M[] filterModels(M : GraphModelInterface)(Graph graph, bool delegate(M) predicate) {
	auto results = array(graph.modelStore!M.filter!((m) => predicate(cast(M)m)));
	return array(results.map!((m) => cast(M)m));
}

/// Returns an array of M from within the graph where key matches value
M[] filterModels(M : GraphModelInterface, string key, V)(Graph graph, V value) {
	return graph.filterModels!(M, (model) => __traits(getMember, model, key) == value);
}


version (unittest) {
	class TestGraphModel : GraphModelInterface {
		mixin GraphModelImplementation;
		override @property string graphId() const { return id; }
		override @property void graphId(string newId) { id = newId; }

		string id;
	}
	
	class Animal : TestGraphModel {
		string name;
	}
	
	class Human : Animal {
		string title;
	}
	
	unittest {
		auto graph = new Graph();
		
		auto david = graph.inject(new Human());
		david.name = "David";
		david.title = "Mr";
		assert(graph.modelStore!Human.length == 1);
		
		auto ginny = graph.inject(new Human());
		ginny.name = "Ginny";
		ginny.title = "Mrs";
		assert(graph.modelStore!Human.length == 2);
		
		auto mia = graph.inject(new Animal());
		mia.name = "Mia";
		assert(graph.modelStore!Animal.length == 1);
		
		auto person = cast(Human)graph.modelStore!Human[0];
		assert(person.name == "David");
		
		assert(graph.filterModels!(Human, (m) => m.name == "David").length == 1);
	}
	
	// Test snapshots
	unittest {
		auto graph = new Graph();
		
		auto david = graph.inject(new Human(), true); // Inject and take snapshot
		david.name = "David";
		david.title = "Mr";
		assert(graph.modelStore!Human.length == 1);
		
		auto ginny = graph.inject(new Human()); // Default is no snapshot
		ginny.name = "Ginny";
		ginny.title = "Miss";
		assert(graph.modelStore!Human.length == 2);
		
		auto mia = graph.inject(new Animal());
		mia.name = "Mia";
		assert(graph.modelStore!Animal.length == 1);
		
		assert(david.graphHasSnapshot);
		
		assert(!ginny.graphHasSnapshot);
		graph.inject(ginny, true); // Take a snapshot
		ginny.title = "Mrs";
		assert(ginny.graphSnapshot["title"] == "Miss");
		auto oldGinny = ginny;
		ginny.revertToSnapshot;
		assert(ginny.title == "Miss");
		assert(oldGinny is ginny);
		
		graph.remove(ginny);
		assert(graph.modelStore!Human.length == 1);
	}
}
