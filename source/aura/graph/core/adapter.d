/**
	* The base functionality for creating an adapter
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.graph.core.adapter;

import aura.graph.core;
import std.format;

/// The basic interface for all Graph Adapters
interface GraphAdapterInterface : GraphInstanceInterface {
	/// Sync all of the models in graph
	bool sync();

	/// Return a serialized `GraphValue` from the given model
	GraphValue serializeToGraphValue(GraphModelInterface model);

	/// Returns true if the adapter handles the given model type
	bool handles(string modelName);
}

/// A base class for Graph Adapters
class GraphAdapter(Models ...) : GraphAdapterInterface {
	mixin GraphInstanceImplementation;
	/// Access the Graph instance associated with this adapter
	@property Graph graph() { return _graph; }

	/// Return the name of the container to be used for the given modelName
	/// by default this returns the typename verbatim. This method can be overridden to return custom containerNames
	static string containerNameFor(string typeName) {
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
}

version (unittest) {
	unittest {
		import std.exception;
		import core.exception;

		class TestVehicle : GraphModelInterface {
			mixin GraphModelImplementation;
			
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
			static string containerNameFor(string typeName) {
				switch (typeName) {
					case "TestVehicle":
						return "vehicles";
					default:
						return typeName;
				}
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