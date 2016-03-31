/**
	* The base functionality for creating an adapter
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.adapter;

import aura.graph;
import std.format;
import std.typetuple;

/// The basic interface for all Graph Adapters
interface GraphAdapterInterface : GraphInstanceInterface {
	/// Return the name of the container to be used for the given modelName
	string containerNameFor(string modelName);

	/// Sync all of the models in graph
	bool sync();

	/// Return a serialized `GraphValue` from the given model
	GraphValue serializeToGraphValue(GraphModelInterface model);

	/// Returns true if the adapter handles the given model type
	bool handles(string modelName);

	/// Returns models where the given key matches the value.
	/// This is a utility function used by Graph and the function implementation does not have do any Graph manipulation
	GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit);
}

/** 
    A base class for Graph Adapters
    
    Functions that need to be overridden are:
        GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit)
*/
class GraphAdapter(Models ...) : GraphAdapterInterface {
	mixin GraphInstanceImplementation;
	/// Access the Graph instance associated with this adapter
	@property Graph graph() { return _graph; }

	/// Set the Graph instance associated with this adapter
	@property void graph(Graph value) { _graph = value; }

	/// Return the name of the container to be used for the given modelName
	/// by default this returns the typename verbatim. This method can be overridden to return custom containerNames
	string containerNameFor(string typeName) {
		return typeName;
	}

	/// Sync all of the models in the given graph
	bool sync() {
		return true;
	}

	/// Returns true if the adapter handles the given model type
	bool handles(string modelName) {
		foreach(model; Models) { 
			if (model.stringof == modelName) return true; 
		}
		return false;
	}

	template handles(M) {
		enum handles = staticIndexOf!(M, TypeTuple!Models) != -1;
	}

	/// Return a serialized `GraphValue` from the given model
	GraphValue serializeToGraphValue(GraphModelInterface model) {
		switch (model.graphType) {
			foreach(ModelType; Models) {
				case ModelType.stringof:
				return aura.graph.value.serializer.serializeToGraphValue(cast(ModelType)model);
			}
			default: assert(false, format("Type '%s' not supported by adapter", model.graphType));
		}
	}

	abstract override GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit);
}

version (unittest) {
	unittest {
		import std.exception;
		import core.exception;

		class TestVehicle : GraphModelInterface {
			mixin GraphModelImplementation;
			string _id;

			override @property string graphId() const { return _id; }
			override @property void graphId(string newId) { _id = newId; }

			string id;
			int wheels;
		}

		class TestCar : TestVehicle {
			int doors;
		}

		class TestMotorbike : TestVehicle {
			bool pillion;
		}

		class MyAdapter : GraphAdapter!(TestVehicle, TestCar) {
			override string containerNameFor(string typeName) {
				switch (typeName) {
					case "TestVehicle":
						return "vehicles";
					default:
						return typeName;
				}
			}

			override GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit) {
				return [];
			}
		}

		GraphAdapterInterface adapter = new MyAdapter();

		auto bike = new TestMotorbike;
		auto car = new TestCar;
		car.wheels = 4;
		car.doors = 4;
		car.id = "TEST-CAR";

		assert ((cast(MyAdapter)adapter).containerNameFor(car.graphType) == "TestCar");
		assert ((cast(MyAdapter)adapter).containerNameFor(TestVehicle.stringof) == "vehicles");

		auto serializedCar = adapter.serializeToGraphValue(cast(GraphModelInterface)car);
		assertThrown!AssertError(adapter.serializeToGraphValue(cast(GraphModelInterface)bike));
	}
}