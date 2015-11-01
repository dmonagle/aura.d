module aura._feature_tests.graph.features;

debug (featureTest) {
	import feature_test;
	import aura.graph.core;
	import aura.graph.mongodb;
	import aura.graph.elasticsearch;

	Graph graphForFeatureTests(bool recreate = false) {
		static Graph graph;
		
		if (!graph || recreate) {
			graph = new Graph;
		}
		
		return graph;
	}
	
	class GraphFeatureTest : FeatureTest {
		
		this() {
			graphForFeatureTests;
		}
		
		@property Graph graph() {
			return graphForFeatureTests;
		}
	}
}
