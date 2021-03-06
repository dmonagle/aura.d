﻿/**
	* Graph Query
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.query;

import aura.graph.graph;
import aura.graph.model;
import aura.graph.adapter;

interface GraphQueryInterface {
	@property bool resolved();
	void resolveGraph();
	void resolveAdapter();
	void resolve();
	void reset();
}

class GraphQueryBase : GraphQueryInterface {
	this() {

	}

	this(Graph graph, GraphAdapterInterface adapter) {
		_graph = graph;
		_adapter = adapter;
	}

	@property bool resolved() { return _resolved; }
	abstract void resolveGraph();
	abstract void resolveAdapter();


	void resolve() {

	}

	void reset() {

	}

protected:
	Graph _graph;
	GraphAdapterInterface _adapter;
	bool _resolved;
}

class GraphQueryOne(M) : GraphQueryBase {
	@property M model() { 
		resolve();
		return _model; 
	}

	this() {
		super();
	}

	this(Graph graph, GraphAdapterInterface adapter) {
		super(graph, adapter);
	}

	alias model this;

protected:
	M _model;
}


version (unittest) {
	class GraphTestUser : GraphModelInterface {
		mixin GraphModelImplementation;
		
		string id;
		string name;

		override @property string graphId() const { return id; }
		override @property void graphId(string newId) { id = newId; }

	}

	class TestAdapter : GraphAdapter!(GraphTestUser) {
		override GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit) {
			return [];
		}
	}

	unittest {
		auto graph = new Graph;
		auto adapter = new TestAdapter;

		class TestUserQuery : GraphQueryOne!GraphTestUser {
			this(Graph graph, GraphAdapterInterface adapter) {
				super(graph, adapter);
			}

			override void resolveGraph() {
				_model = new GraphTestUser;
			}

			override void resolveAdapter() {
				_model = new GraphTestUser;
			}
		}

		auto query = new TestUserQuery(graph, adapter);
		assert(!query.resolved);

		/*
		assert(!belongsTo.resolved);
		
		auto user = new GraphTestUser;
		user.name = "David";
		
		belongsTo = user;
		
		assert(belongsTo.resolved);
		assert(belongsTo.name == "David");
		*/
	}
	
}