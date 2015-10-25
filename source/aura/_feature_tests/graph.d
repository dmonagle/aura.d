module aura._feature_tests.graph;

debug (featureTest) {
	import feature_test;

	unittest {
		feature("Graph store and retrieve", (f) {
				f.scenario("Create a graph and store models in it", {
						featureTestPending;
					});			
			}, "graph");
	}
}