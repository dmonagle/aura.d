module aura.graph.tests.integration;


version (unittest) {
	import std.typetuple;
	import vibe.core.log;
	
	import std.algorithm;
	
	import aura.graph.core;
	import aura.graph.mongodb;
	import aura.graph.elasticsearch;

	class Person : AppGraph.Model {
		string firstName;
		string surname;
		int age;

		@graphEmbedded Employment[] employments;
	}

	class Employment : AppGraph.Model {
		string role;
		string companyReference;
	}

	class Company : AppGraph.Model {
		string name;
		string reference;
	}

	alias GraphModels = TypeTuple!(Company, Person);

	class AppGraph : Graph!(AppMongoAdapter, AppEsAdapter) {
		alias mongoAdapter = adapter!AppMongoAdapter;
		alias esAdapter = adapter!AppEsAdapter;

		static this() {
			mongoAdapter.url = "mongodb://mongodb";
			mongoAdapter.databaseName = "aura_graph_unittest";
			
			esAdapter.hosts = ["http://elasticsearch:9200"];
			esAdapter.databaseName = "aura_graph_unittest";
		}

		this() {
			addIndex!(Company, "reference");
		}
	}
	
	
	class AppMongoAdapter : GraphMongoAdapter!GraphModels {
		this() {

		}
	}

	class AppEsAdapter : GraphEsAdapter!Person {
		this() {
			
		}
	}


	AppGraph createGraph() {
		AppGraph graph = new AppGraph;

		return graph;
	}

	void dropUnittestCollections(AppGraph graph) {
		alias mongoAdapter = graph.adapter!AppMongoAdapter;
		alias esAdapter = graph.adapter!AppEsAdapter;

		mongoAdapter.dropCollection!Company;
		mongoAdapter.dropCollection!Person;
	}
}

unittest {
	AppGraph graph = createGraph;
	graph.dropUnittestCollections;

	assert(graph.adapterFor!Company, "The graph should return a valid adapter");
	assert(graph.hasIndex!Company("reference"), "The graph should now have an index");

	assert(!graph.needsSync, "The graph should not need sycning");
	assert(!graph.unsyncedCount, "The graph unsynced should be zero");

	Company company = new Company;
	company.reference = "ABC123";
	company.name = "ACME";
	graph.inject(company);

	assert(company.graphInstance == graph);
	assert(company.graphNeedsSync);
	assert(graph.needsSync, "The graph should need sycning");
	assert(graph.unsyncedCount == 1, "The graph unsynced count should be 1");

	graph.sync();

	assert(!graph.needsSync, "The graph should not need sycning");
	assert(!graph.unsyncedCount, "The graph unsynced should be zero");
	assert(!company.graphNeedsSync);

	auto companyCopy = graph.find!Company(company.graphState.id);

	assert(companyCopy == company);

	company.graphDelete;
	graph.sync();
	auto nothing = graph.find!Company(company.graphState.id);
	assert(!nothing, "The delete record should not be returned");
}

unittest {
	AppGraph graph = createGraph;
	graph.dropUnittestCollections;

	auto company = new Company;
	company.name = "Ministry of Magic";
	company.reference = "MoM";

	auto person = new Person;
	person.firstName = "Harry";
	person.surname = "Potter";
	person.age = 30;

	auto employment = new Employment;
	employment.companyReference = "MoM";
	employment.role = "Auror";

	person.employments ~= employment;

	graph.inject(person);
	graph.inject(company);

	assert(graph.unsyncedCount == 2);
	assert(person.employments[0].graphInstance == graph, "The graph instance should be set on embedded objects");

	auto employment2 = new Employment;
	employment2.companyReference = "None";
	employment2.role = "Unknown";
	person.employments ~= employment2;

	assert(!person.employments[1].graphInstance, "The graph should not be set");
	graph.ensureGraphReferences(person);
	assert(person.employments[1].graphInstance == graph, "The graph should be set");

	graph.sync;

	person.age = 31;
	person.graphTouch;
	graph.sync;

	auto graph2 = createGraph;
	auto loadedPerson = graph2.find!Person(person.graphState.id);
	assert (loadedPerson.employments[0].graphInstance == graph2, "The graphInstance of embedded items should be the same as the instance that loaded the parent");
	assert(loadedPerson, "The person should have been loaded from the database");
	auto firstEmployment = loadedPerson.employments[0];
	auto companyRef = firstEmployment.companyReference;
	auto company2 = graph2.find!(Company, "reference")(companyRef);
	auto company3 = graph2.find!(Company, "reference")(companyRef);
	assert(company2 == company3);
	assert(cast(Person)firstEmployment.graphParent == loadedPerson);
}

unittest {
	import aura.data.bson;

	auto graph = createGraph;

	auto person = new Person;
	person.firstName = "Hermione";
	person.surname = "Granger";
	person.age = 30;
	
	auto employment = new Employment;
	employment.companyReference = "MoM";
	employment.role = "Deputy Head";
	person.employments ~= employment;
	graph.inject(person);
	graph.sync;

	auto models = graph.query!Person((graph) {
			alias a = graph.adapter!AppMongoAdapter;
			auto results = a.query!Person(Bson.emptyObject);
			logDebugV("Number of results in query: %s", results.length);
			return results;
		});

	assert(models.length == 2, "Should have returned both Person records");
	assert(models.canFind(person), "The original person record should be in the retured value");
}