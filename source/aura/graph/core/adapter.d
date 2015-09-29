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

interface GraphAdapterInterface {
	/// Return the name of the container to be used for the given modelName
	string containerNameFor(string modelName);
	/// Sync all of the models in the given graph
	bool sync(Graph graph);

	/// Return a serialized `GraphValue` from the given model
	GraphValue serializeToGraphValue(GraphModelInterface model);
}

///
class GraphAdapter(Models ...) : GraphAdapterInterface {
	/// Return the name of the container to be used for the given modelName
	string containerNameFor(string typeName) {
		import aura.util.string_transforms;
		return typeName.snakeCase;
	}

	/// Sync all of the models in the given graph
	bool sync(Graph graph) {
		return true;
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
			override string containerNameFor(string typeName) {
				switch (typeName) {
					case "TestVehicle":
						return "vehicles";
					default:
						return super.containerNameFor(typeName);
				}
			}
		}

		GraphAdapterInterface adapter = new MyAdapter();

		auto bike = new TestMotorbike;
		auto car = new TestCar;
		car.wheels = 4;
		car.doors = 4;
		car.id = "TEST-CAR";

		assert (adapter.containerNameFor(car.graphType) == "test_car");
		assert (adapter.containerNameFor(TestVehicle.stringof) == "vehicles");

		auto serializedCar = adapter.serializeToGraphValue(cast(GraphModelInterface)car);
		assertThrown!AssertError(adapter.serializeToGraphValue(cast(GraphModelInterface)bike));
	}
}