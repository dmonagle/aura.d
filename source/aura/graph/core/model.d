/**
	* Graph Model
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.core.model;

public import aura.graph.value;
public import vibe.data.serialization;

import aura.graph.core.graph;

import std.algorithm;
import std.array;

/// Adds a property to a class that will return the class name at runtime. Works on base classes to return the child class type
/// Eg. const graph.graph.Graph is returned as Graph
mixin template GraphTypeProperty() {
	/// Returns a string representation of the class name
	/// Removes const and namespaceing so it should match the name of the class called with stringof
	@ignore @property string graphType() const {
		import std.string;
		import std.regex;
		
		auto constMatch = ctRegex!`^const\((.*)\)$`;
		auto typeString = typeid(this).toString();
		
		// Remove the const qualifier 
		if (auto matches = typeString.matchFirst(constMatch)) typeString = matches[1];
		
		// Return the text after the last .
		return typeString.split(".")[$ - 1];
	}
}


interface GraphModelInterface : GraphInstanceInterface {
	@property string graphType() const;

	/// Returns a unique string depicting this model
	@property string graphId() const;
	@property void graphId(string);

	/// Returns true if the model has been persisted to it's primary storage
	@property bool graphPersisted() const;
	@property void graphPersisted(bool value);
	
	/// If true, all changes have been synced
	@property bool graphSynced() const;

	void graphTouch();
	void graphUntouch();
	
	@property bool graphDeleted() const;
	void graphDelete();
	void graphUndelete();

	@property inout(GraphModelInterface) graphParent() inout;
	@property void graphParent(GraphModelInterface value);

	
	bool graphHasSnapshot() const;
	void clearGraphSnapshot();
	@property ref GraphValue graphSnapshot();
	@property GraphValue graphSnapshot() const;
}

/// Mixin to implement basic functionality to a `GraphModelInterface`
mixin template GraphModelImplementation() {
	mixin GraphTypeProperty;
	mixin GraphInstanceImplementation;

	@ignore bool graphPersisted() const { return _graphPersisted; }
	void graphPersisted(bool value) { _graphPersisted = value;}
	
	@ignore @property bool graphSynced() const { return _graphSynced; }
	void graphTouch() { _graphSynced = false; }
	void graphUntouch() { _graphSynced = true; }
	
	bool graphDeleted() const { return _graphDeleted; }
	void graphDelete() { _graphDeleted = true; }
	void graphUndelete() { _graphDeleted = false; }

	@ignore @property inout(GraphModelInterface) graphParent() inout { return _graphParent; }
	@property void graphParent(GraphModelInterface value) { _graphParent = value; }

	bool graphHasSnapshot() const {
		return _snapshot.isNull ? false : true;
	}
	
	void clearGraphSnapshot() {
		_snapshot = null;
	}
	
	@ignore @property ref GraphValue graphSnapshot() {
		return _snapshot;
	}
	
	@property GraphValue graphSnapshot() const {
		return _snapshot;
	}
	
private:
	GraphValue _snapshot;
	GraphModelInterface _graphParent;
	bool _graphPersisted;
	bool _graphSynced;
	bool _graphDeleted;
}

/// Default impolementation of GraphModelInterface
class GraphModel : GraphModelInterface {
	mixin GraphModelImplementation;

	override abstract @property string graphId() const;
	override abstract @property void graphId(string);
}

/// Copy the serializable attributes from source to destination
M copyGraphAttributes(M : GraphModelInterface)(ref M dest, const ref M source) {
	import aura.graph.serialization;
	foreach (i, mname; SerializableFields!M) {
		__traits(getMember, dest, mname) = __traits(getMember, source, mname);
	}
	return dest;
}

/// Merge the GraphValue data into the given model
M merge(M : GraphModelInterface)(ref M model, GraphValue data) {
	auto attributes = serializeToGraphValue(model);
	auto newModel = deserializeGraphValue!M(aura.graph.value.helpers.merge(attributes, data));
	model.copyGraphAttributes(newModel);
	
	return model;
}

/// Creates a snapshot of the model
GraphValue takeSnapshot(M : GraphModelInterface)(M model) {
	model.graphSnapshot = serializeToGraphValue(model);
	return model.graphSnapshot;
}


/// Reverts the model back to the snapshot state if the snapshot exists
void revertToSnapshot(M : GraphModelInterface)(M model) 
in {
	assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
}
body {
	if (!model.graphHasSnapshot) return;
	auto reverted = deserializeGraphValue!M(model.graphSnapshot);
	model.copyGraphAttributes(reverted);
}

/// Returns a `GraphValue` with the difference between the current state and the snapshot
GraphValue diffFromSnapshot(M : GraphModelInterface)(M model) 
in {
	assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
}
body {
	import aura.graph.value.diff;
	auto currentState = serializeToGraphValue(model);
	if (!model.graphHasSnapshot) return currentState;
	return model.graphSnapshot.diff(currentState);
}

version (unittest) {
	class Person : GraphModelInterface {
		mixin GraphModelImplementation;

		string _id;
		string firstName;
		string surname;
		int age;
		double wage;

		override @property string graphId() const { return _id; }
		override @property void graphId(string newId) { _id = newId; }
	}
	
	unittest {
		auto person = new Person;
		person.surname = "Monagle";
		auto data = GraphValue.emptyObject;
		data["firstName"] = "David";
		person.merge(data);
		assert(person.surname == "Monagle");
		assert(person.firstName == "David");
	}
}

alias GraphModelStore = GraphModelInterface[];

/// Mixes in modelStore functionality 
mixin template GraphModelStoreImplementation() {
	/// Returns the modelStore for the given model type
	ref GraphModelStore modelStore(string storeName) {
		if (storeName !in _graphModelStores) return (_graphModelStores[storeName] = []);
		return _graphModelStores[storeName];
	}

	/// Returns the total number of models across all stores
	ulong modelCount() const {
		ulong count;
		foreach(store; _graphModelStores) count += store.length;
		return count;
	}

	/// ditto
	ref GraphModelStore modelStore(M)() {
		return modelStore(M.stringof);
	}

	/// Clears all data from the modelStores
	void clearModelStores() {
		_graphModelStores = GraphModelStore[string].init;
	}

	/// Clears the modelStore for the given model
	void clearModelStore(M)() {
		if (storeName in _graphModelStores) {
			_graphModelStores[storeName] = GraphModelStore.init;
		}
	}


private:
	GraphModelStore[string] _graphModelStores;
}

/// Removes the given model from the store
void removeModel(M : GraphModelInterface)(ref GraphModelStore store, M model) {
	store = array(store.filter!((m) => m !is model));
}

/// Adds the given model to the store if it doesn't alrady exist
bool addModel(M : GraphModelInterface)(ref GraphModelStore store, M model) {
	if (!store.canFind(model)) {
		store ~= model;
		return true;
	}
	return false;
}
