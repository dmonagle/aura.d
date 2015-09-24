/**
	* Graph Model
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.core.model;

import aura.graph.core.graph;
import aura.graph.value;
import vibe.data.serialization;

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


interface GraphModelInterface {
	@property string graphType() const;
	
	@property bool graphPersisted() const;
	@property void graphPersisted(bool value);
	
	@property bool graphSynced() const;
	void graphTouch();
	void graphUntouch();
	
	@property bool graphDeleted() const;
	void graphDelete();
	void graphUndelete();
	
	@property inout(Graph) graphInstance() inout;
	@property void graphInstance(Graph value);
	
	GraphValue toGraphValue();
	bool graphHasSnapshot() const;
	void clearGraphSnapshot();
	@property ref GraphValue graphSnapshot();
	@property GraphValue graphSnapshot() const;
}

/// Mixin to implement basic functionality to a `GraphModelInterface`
mixin template GraphModelImplementation() {
	mixin GraphTypeProperty;
	
	@ignore bool graphPersisted() const { return _graphPersisted; }
	void graphPersisted(bool value) { _graphPersisted = value;}
	
	@ignore @property bool graphSynced() const { return _graphSynced; }
	void graphTouch() { _graphSynced = false; }
	void graphUntouch() { _graphSynced = true; }
	
	bool graphDeleted() const { return _graphDeleted; }
	void graphDelete() { _graphDeleted = true; }
	void graphUndelete() { _graphDeleted = false; }
	
	@ignore @property inout(Graph) graphInstance() inout { return _graphInstance; }
	@property Graph graphInstance() { return _graphInstance; }
	@property void graphInstance(Graph value) { _graphInstance = value; }
	
	GraphValue toGraphValue() { 
		return serialize!GraphValueSerializer(this);
	}
	
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
	Graph _graphInstance;
	GraphValue _snapshot;
	bool _graphPersisted;
	bool _graphSynced;
	bool _graphDeleted;
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
	auto attributes = Graph.serializeModel(model);
	auto newModel = Graph.deserializeModel!M(aura.graph.value.helpers.merge(attributes, data));
	model.copyGraphAttributes(newModel);
	
	return model;
}

version (unittest) {
	class Person : GraphModelInterface {
		mixin GraphModelImplementation;
		
		string firstName;
		string surname;
		int age;
		double wage;
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