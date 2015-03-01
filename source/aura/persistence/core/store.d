module aura.persistence.core.store;

import aura.persistence.core.adapter;
import aura.persistence.core.model;
import aura.util.string_transforms;

import vibe.data.serialization;

import std.typetuple;
import std.traits;
import std.conv;
import std.datetime;
import core.time;
import std.algorithm;

import std.stdio;
import colorize;

/// Caches and indexes model references with ability to expire
class ModelCache {
	this() {
		_storeLife = 3.seconds;
	}

	struct IndexMeta {
		string function(ModelInterface) getKey;
	}

	void addIndex(string key)(string function(ModelInterface) getKey) {
		_indexMeta[key] = IndexMeta(getKey);
	}

	void addIndex(M, string attribute)() {
		addIndex!attribute((model) => __traits(getMember, cast(M)model, attribute));
	}

	void inject(ModelInterface m) {
		_store[""][m.persistenceId] = m;
		touch(m);
		foreach (key, meta; _indexMeta) {
			_store[key][meta.getKey(m)] = m;
		}
	}

	void clean() {
		foreach(id, model; _store[""])
			if (hasExpired(model)) remove(model);
	}
	
	void remove(ModelInterface m) {
		_store[""].remove(m.persistenceId);
		_expiryTime.remove(m.persistenceId);
		foreach (key, meta; _indexMeta) {
			_store[key].remove(meta.getKey(m));
		}
	}
	
	void touch(ModelInterface m) {
		_expiryTime[m.persistenceId] = Clock.currTime + _storeLife;
	}
	
	bool hasExpired(ModelInterface m) {
		return Clock.currTime >= _expiryTime[m.persistenceId];
	}
	
	ModelInterface[string] opIndex(string key) {
		return _store[key];
	}

	void add(string key, string id, ModelInterface model) {
	}

	ModelInterface get(M)(string key, string id) {
		ModelInterface model;
		assert(key == "" || key in _indexMeta, "Attempted to look up unregistered key '" ~ key ~ "` in store for model '" ~ M.stringof ~ "'");
		if (key !in _store) return model; // Return if nothing has been put into the index yet

		auto models = _store[key];
		if (id in models) model = models[id];
		return cast(M)model;
	}

	ModelInterface get(M)(string id) {
		return get!M("", id);
	}

private:
	Duration _storeLife;
	IndexMeta[string] _indexMeta;
	SysTime[string] _expiryTime;
	ModelInterface[string][string] _store;
}

version (unittest) {
	unittest {
		class TestModelBase : ModelInterface {
			mixin PersistenceTypeProperty;
			@ignore @property string persistenceId() const { return _id; }
			@property void persistenceId(string id) { _id = id; }
			void ensureId() {}
			@ignore @property bool isNew() const { return false; }

			string _id;
		}
		
		class Person : TestModelBase {
			string firstName;
			string surname;
			string companyReference;
		}

		auto modelStore = new ModelCache;
		modelStore.addIndex!(Person, "firstName");

		Person person = new Person();
		person._id = "1";
		person.firstName = "David";

		modelStore.inject(person);

		assert(!modelStore.get!Person("2"));
		assert(modelStore.get!Person("1"));

		auto personClone = modelStore.get!Person("1");
		assert(personClone == person);

		assert(!modelStore.get!Person("firstName", "Fred"));
		assert(modelStore.get!Person("firstName", "David") == person);
	}
}


class PersistenceStore(A ...) {
	alias AdapterTypes = TypeTuple!A;
	alias ModelTypes = NoDuplicates!(staticMap!(adapterModels, AdapterTypes));

	// Make sure that each adapter is only added once
	static assert (AdapterTypes.length == NoDuplicates!(AdapterTypes).length, "Store can not have more than one of the same type of adapter");

	/// Returns the adapters types that have the model M registered
	template adapterTypesFor(M) {
		alias adapterTypesFor = Filter!(RegisteredModel!M.inAdapter, AdapterTypes);
	}

	/// Returns the first adapter type that has the model M registered
	template adapterTypeFor(M) {
		alias adapters = adapterTypesFor!M;
		static assert(adapters.length, "No adapter found in store for model " ~ M.stringof);
		alias adapterTypeFor = adapters[0];
	}

	/// Returns the first registered adapter for the give model (M)
	template adapterFor(M) {
		alias adapterFor = adapter!(adapterTypeFor!M);
	}

	/// Returns the sharedInstance of the store
	static @property PersistenceStore!A instance() {
		static PersistenceStore!A _store;

		if (!_store) _store = new PersistenceStore!A;

		return _store;
	}

	static @property T instanceAs(T)() {
		return cast(T)instance();
	}

	// Returns a lazy initialized adapter at the given index, cast into A. 
	static @property A adapter(A)() {
		auto index = staticIndexOf!(A, AdapterTypes);
		auto a = _adapters[index];
		if (a) return cast(A)a;
		a = new A();
		_adapters[index] = a;
		return cast(A)a;
	}

	bool save(M)(M model) {
		bool result = true;

		foreach(AdapterType; AdapterTypes) {
			auto a = adapter!AdapterType;
			static if (a.modelIsRegistered!M) {
				if (!a.save(model)) result = false;
			}
		}

		// Inject the model into the store (has no effect if it's already there)
		inject(model);

		return result;
	}

	void inject(M : ModelInterface)(M m) {
		assert(!m.isNew, "Attempt to inject a model into a store before it has an id.");
		modelStore!M.inject(m);
		ensureEmbedded!((embeddedModel) {
				embeddedModel.ensureId;
			})(m);
	}

	void inject(M : ModelInterface)(M[] models) {
		foreach(m; models) inject(m);
	}

	void addIndex(M, string key)(string function(ModelInterface) getKey) {
		modelStore!M.addIndex!key(getKey);
	}
	
	void addIndex(M, string attribute)() {
		modelStore!M.addIndex!(M, attribute);
	}
	
	M findInStore(M, string key = "", T)(const T id) {
		return cast(M)modelStore!M.get!M(key, id.to!string);
	}

	void query(M, A : PersistenceAdapterInterface, T)(T q, scope void delegate(M) action, uint limit = 0) {
		M[] returnModels;
		
		auto adapter = adapter!A;
		adapter.storeQuery!M(this, q, (model) { 
			inject(model);
			action(model);
		}, limit);
	}

	void query(M, T)(T q, scope void delegate(M) action, uint limit = 0) {
		query!(M, adapterTypeFor!M)(q, action, limit);
	}

	M[] query(M, A : PersistenceAdapterInterface, T)(T q, uint limit = 0) {
		M[] returnModels;

		query!(M, A)(q, (model) { returnModels ~= model; }, limit);

		return returnModels;
	}

	M[] query(M, T)(T q, uint limit = 0) {
		return query!(M, adapterTypeFor!M)(q, limit);
	}

	M[] findMany(M, string key = "", IdType)(const IdType[] ids ...) {
		M[] returnModels;
		IdType[] adapterSearchIds;

		foreach(id; ids) {
			auto result = findInStore!(M, key)(id);
			if (result) {
				returnModels ~= result;
			}
			else {
				adapterSearchIds ~= id;
			}
		}

		if (adapterSearchIds.length) {
			auto adapter = adapterFor!M;
			auto adapterModels = adapter.storeFindMany!(M, key)(this, adapterSearchIds);
			returnModels ~= adapterModels;
			inject!M(adapterModels);
		}

		return returnModels;
	}

	M findOne(M, string key = "", IdType)(const IdType id) {
		M returnModel = findInStore!(M, key)(id);
		
		if (!returnModel) {
			auto adapter = adapterFor!M;
			returnModel = adapter.storeFindOne!(M, key)(this, id);
			if (returnModel) inject!M(returnModel);
		}
		
		return returnModel;
	}

private:
	// Returns the store object for the given model
	@property ModelCache modelStore(M)() {
		auto i = staticIndexOf!(M, ModelTypes);
		assert(i != -1, "Attempted to look up store for unregistered model: " ~ M.stringof);
		auto ms = _modelStore[i];
		if (ms) return ms;
		ms = new ModelCache;
		_modelStore[i] = ms;
		return ms;
	}
	
	struct IndexMeta {
		string name;
		string function(ModelInterface) getKey;
	}

	template adapterModels(A) {
		alias adapterModels = A.ModelTypes;
	}

	struct RegisteredModel(M) {
		static template inAdapter(A) {
			immutable bool inAdapter = staticIndexOf!(M, A.ModelTypes) != -1;
		}
	}

	static PersistenceAdapterInterface[AdapterTypes.length] _adapters;
	ModelCache[ModelTypes.length] _modelStore;
}

debug (persistenceIntegration) {
	version (unittest) {
		import aura.persistence.core.relations;

		class TestModelBase : ModelInterface {
			mixin PersistenceTypeProperty;
			@ignore @property string persistenceId() const { return _id; }
			@property void persistenceId(string id) { _id = id; }
			void ensureId() {}
			@ignore @property bool isNew() const { return false; }

			string _id;
		}

		class Person : TestModelBase {
			string firstName;
			string surname;
			string companyReference;

			mixin BelongsTo!(ApplicationStore, Company, "", "companyReference", "reference");
		}

		class Company : TestModelBase {
			string name;
			string reference;
		}

		class Adapter1 : PersistenceAdapter!(Person, Company) {
			bool save(M)(const M model) {
				writeln("Adapter 1 is saving".color(fg.light_blue));
				return true;
			}
			
			ModelType[] storeFindMany(ModelType, string key = "", StoreType, IdType)(StoreType s, const IdType[] ids ...) {
				ModelType[] models;
				return models;
			}
			
			ModelType storeFindOne(ModelType, string key = "", StoreType, IdType)(StoreType store, const IdType id) {
				ModelType model;
				return model;
			}
		}
		
		class Adapter2 : PersistenceAdapter!(Company) {
			bool save(M)(const M model) {
				writeln("Adapter 2 is saving".color(fg.light_cyan));
				return true;
			}
		}
		
		class ApplicationStore : PersistenceStore!(Adapter1, Adapter2) {
		}


		unittest {

			auto sharedStore =  ApplicationStore.instance;

			auto person = sharedStore.findInStore!Person("fakeId");
			assert(!person);
			person = new Person;
			person.firstName = "David";
			person.surname = "Monagle";
			person.companyReference = "aura-001";
			person.persistenceId = "1";
			sharedStore.inject(person);

			auto lookup = sharedStore.findInStore!Person("0");
			assert(!lookup);
			lookup = sharedStore.findInStore!Person("1");
			assert(lookup == person);

			sharedStore.addIndex!(Company, "reference");
			auto company = new Company;
			company.name = "Aura Inc";
			company.reference = "aura-001";
			company.persistenceId = "1";
			sharedStore.inject(company);
			auto lookupCompany = sharedStore.findInStore!(Company, "reference")("1");
			assert(!lookupCompany);
			lookupCompany = sharedStore.findInStore!(Company, "reference")("aura-001");
			assert(lookupCompany == company);

			auto many = sharedStore.findMany!(Company, "reference")("aura-001", "aura-002");
			assert(many.length == 1, "Expected length of 1 but got " ~ many.length.to!string);
			assert(many[0].reference == "aura-001");

			auto one = sharedStore.findOne!(Company, "reference")("aura-001");
			assert(one.reference == "aura-001");

			sharedStore.save(one);

			//auto foreignCompany = sharedStore.findOne!(Company, "reference")(person.companyReference);
			auto foreignCompany = person.company;
			assert(foreignCompany == company);

			assert(sharedStore.adapter!Adapter1.containerName!Company == "companies");
			sharedStore.adapter!Adapter1.containerName!Company = "kompaniez";
			assert(sharedStore.adapter!Adapter1.containerName!Company == "kompaniez");

			auto newStore = new ApplicationStore;

			assert (newStore.adapter!Adapter1 == sharedStore.adapter!Adapter1);
		}
	}
}