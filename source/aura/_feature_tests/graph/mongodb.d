module aura._feature_tests.graph.mongodb;

debug (featureTest) {
	import feature_test;
	import aura.graph.core;
	import aura.graph.mongodb;
	import aura.graph.elasticsearch;
	import aura._feature_tests.graph.features;

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
		}
	}

	unittest {
		feature("Graph store and retrieve", (f) {
				f.scenario("Create a graph and store models in it", {
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

						mia.graphDelete;
						graph.sync.shouldBeTrue();
					});			
			}, "graph");
		feature("Find models using mongodb adapter", (f) {
				f.scenario("Find a model by id", {
						auto graph = new TestPetGraph;
						auto mongoAdapter = cast(TestMongoDBAdapter)graph.adapter;

						mongoAdapter.dropCollection!TestUser;
						mongoAdapter.dropCollection!TestPet;
						
						graph.adapter.shouldBeTrue;
						auto david = graph.inject(new TestUser);
						david.firstName = "David";
						david.surname = "Monagle";
						graph.sync.shouldBeTrue;

						david._id.valid.shouldBeTrue;

						auto found = graph.find!(TestUser, "firstName")("David");
						found.shouldBeTrue;
						f.info("%s", found.serializeToPrettyJson);
						assert(found is david, "Found should be David, but it is not");

						graph.clearModelStores();
						auto cursor = mongoAdapter.getCollection!TestUser.find(["_id": david._id]);
						auto results = mongoAdapter.injectCursor!TestUser(cursor);
						results.length.shouldEqual(1);

						auto secondResult = mongoAdapter.find!TestUser(david._id);
						assert(secondResult is results[0], "The results should be the same instance");
					});
				f.scenario("MonogAdapter find for graph", {
						auto graph = new TestPetGraph;
						auto results = graph.adapter.graphFind("TestUser", "surname", GraphValue("Monagle"), 1);

						results.length.shouldEqual(1);
						auto user = cast(TestUser)results[0];
						user.firstName.shouldEqual("David");
						user.graphPersisted.shouldBeTrue;
					});
				f.scenario("Graph find", {
						auto graph = new TestPetGraph;
						auto mongoAdapter = cast(TestMongoDBAdapter)graph.adapter;

						auto result = graph.find!(TestUser, "firstName")("David");
						result.shouldBeTrue;
						result.surname.shouldEqual("Monagle");
						graph.length.shouldEqual(1);

						auto notFound = graph.find!(TestUser, "firstName")("Kevin");
						notFound.shouldBeFalse;

						auto result2 = graph.find!(TestUser, "firstName")("David");
						result2.shouldBeTrue;
						assert(result is result2);
						graph.length.shouldEqual(1);
					});
			});
	}
}