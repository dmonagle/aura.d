﻿/**
	* Graph Storage Class
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.core.graph;

import aura.graph.core.model;

import aura.graph.value;
import vibe.data.serialization;

import std.algorithm;
import std.array;

/// Main storage class for Graph
class Graph {
	static GraphValue serializeModel(M : GraphModelInterface)(M model) {
		return serialize!GraphValueSerializer(model);
	}
	
	static M deserializeModel(M : GraphModelInterface)(GraphValue value) {
		return deserialize!(GraphValueSerializer, M)(value);
	}
	
	M inject(M : GraphModelInterface)(M model, bool snapshot = true) 
	in {
		assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
	}
	body {
		if (model.graphInstance !is this) {
			model.graphInstance = this;
			modelStore!M ~= model;
		}
		if (snapshot) model.graphSnapshot = serializeModel(model);
		return model;
	}

	/// Reverts the model back to the snapshot state if the snapshot exists
	void revert(M : GraphModelInterface)(ref M model) 
	in {
		assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
	}
	body {
		if (model.graphInstance !is this) return;
		if (!model.graphHasSnapshot) return;
		auto reverted = deserializeModel!M(model.graphSnapshot);
		model.copyGraphAttributes(reverted);
	}


	ref GraphModelInterface[] modelStore(M)() {
		if (M.stringof !in _store) return (_store[M.stringof] = []);
		return _store[M.stringof];
	}

private:
	GraphModelInterface[][string] _store;
}

/// Returns an array of M from within the graph that match the given predicate
M[] filterModels(M : GraphModelInterface, alias predicate = (m) => true)(Graph graph) {
	auto results = array(graph.modelStore!M.filter!((m) => predicate(cast(M)m)));
	return array(results.map!((m) => cast(M)m));
}

version (unittest) {
	class GraphModel : GraphModelInterface {
		mixin GraphModelImplementation;

		string id;
	}

	class Animal : GraphModel {
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
		
		auto david = graph.inject(new Human());
		david.name = "David";
		david.title = "Mr";
		assert(graph.modelStore!Human.length == 1);
		
		auto ginny = graph.inject(new Human(), false);
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
		graph.revert(ginny);
		assert(ginny.title == "Miss");
		assert(oldGinny is ginny);
	}
}
