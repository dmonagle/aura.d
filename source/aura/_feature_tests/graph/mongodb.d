module aura._feature_tests.graph.mongodb;

debug (featureTest) {
	import feature_test;
	import aura.graph.core;
	import aura.graph.mongodb;
	import aura.graph.elasticsearch;

	class TestUser : GraphMongoModel {
		string firstName;
		string surname;
	}

	enum TestPetSpecies {
		dog,
		cat,
		bird,
		fish
	}

	class TestPet : GraphMongoModel {
		string name;
		string color;
		@byName TestPetSpecies species;
		BsonObjectID userId;
	}

	class TestNotStoredModel : GraphMongoModel {
	}

	class ElasticSearchIndexer : ElasticsearchIndexProxy!(TestUser, TestPet) {
		static this() {
			hosts = ["http://127.0.0.1:9200"];
			prefix = "test_aura_graph_";
		}
	}

	class TestMongoDBAdapter : GraphMongoAdapter!(TestUser, TestPet) {
		static this() {
			databaseName = "test_aura_graph";
			url = "localhost";
		}

		override string containerNameFor(string typeName) {
			switch (typeName) {
				case "TestPet":
					return "pets";
				default:
					return typeName;
			}
		}
	}

	class TestPetGraph : Graph {
		this() {
			adapter = new TestMongoDBAdapter;
			esIndexer = new ElasticSearchIndexer;
			registerGraphEventListener(esIndexer);
		}

		ElasticSearchIndexer esIndexer;
	}

	unittest {
		feature("Graph store and retrieve", (f) {
				f.scenario("Create a graph and store models in it", {
						import vibe.core.log;
						setLogLevel(LogLevel.debugV);

						f.info("Dropping collections");
						auto graph = new TestPetGraph;
						auto mongoAdapter = cast(TestMongoDBAdapter)graph.adapter;

						mongoAdapter.dropCollection!TestUser;
						mongoAdapter.dropCollection!TestPet;

						graph.adapter.shouldBeTrue;
						graph.adapter.handles("TestUser").shouldBeTrue;
						graph.adapter.handles("TestPet").shouldBeTrue;
						graph.adapter.handles("TestNotStoredModel").shouldBeFalse;

						auto david = graph.inject(new TestUser);
						david.firstName = "David";
						david.surname = "Monagle";
						david.graphHasSnapshot.shouldBeFalse;
						
						auto mia = graph.inject(new TestPet);
						mia.name = "Mia";
						mia.species = TestPetSpecies.dog;
						mia.graphHasSnapshot.shouldBeFalse;

						david.graphPersisted.shouldBeFalse;
						mia.graphPersisted.shouldBeFalse;

						graph.sync.shouldBeTrue();

						david.graphPersisted.shouldBeTrue;
						david.graphHasSnapshot.shouldBeTrue;
						mia.graphPersisted.shouldBeTrue;
						mia.graphHasSnapshot.shouldBeTrue;

						mia.color = "Black";
						graph.sync.shouldBeTrue();

						graph.esIndexer.modelCount.shouldEqual(2);

						mia.graphDelete;
						graph.sync.shouldBeTrue();

						graph.esIndexer.modelCount.shouldEqual(1);
					});			
			}, "graph");
	}
}