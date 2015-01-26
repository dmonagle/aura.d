module aura.persistence.core.store;

import aura.persistence.core.adapter;
import aura.persistence.core.model;
import aura.util.string_transforms;

import vibe.data.serialization;

import std.typetuple;
import std.conv;

import std.stdio;
import colorize;

class PersistenceStore(A ...) {
	alias AdapterTypes = TypeTuple!A;

	// Make sure that each adapter is only added once
	static assert (AdapterTypes.length == NoDuplicates!(AdapterTypes).length, "Store can not have more than one of the same type of adapter");

	this() {
		foreach(A; AdapterTypes) {
			_adapters ~= new A();
		}
		foreach(M; ModelTypes) {
			writeln(M.stringof.color(fg.green));
		}
	}

	static @property PersistenceStore!A instance() {
		static PersistenceStore!A _store;
		if (!_store) {
			_store = new PersistenceStore!A();
		}
		return _store;
	}

	/// Returns the instance of the give adapter type
	@property A adapter(A)() {
		auto index = staticIndexOf!(A, AdapterTypes);
		return cast(A)_adapters[index];
	}

	bool save(M)(const M model) {
		bool result = true;

		foreach(index, AdapterType; AdapterTypes) {
			auto adapter = cast(AdapterType)(_adapters[index]);
			if (adapter.modelIsRegistered!M) {
				if (!adapter.save(model)) result = false;
			}
		}

		return result;
	}


	// Returns the store object for the given model
	ref M[string][string] modelStore(M)() {
		return mixin("_" ~ M.stringof.camelCaseLower ~ "Store");
	}

	void inject(M : ModelInterface)(M m) {
		modelStore!M[""][m.persistenceId] = m;
		if (M.stringof in _indexMeta) {
			auto meta = _indexMeta[M.stringof];
			modelStore!M[meta.name][meta.getKey(m)] = m;
		}
	}

	void addIndex(M)(string name, string function(ModelInterface) getKey) {
		_indexMeta[M.stringof] = IndexMeta(name, getKey);
	}
	
	void addIndex(M, string attribute)() {
		addIndex!M(attribute, (model) => mixin("(cast(" ~ M.stringof ~ ")model)." ~ attribute));
	}
	
	M findInStore(M, string index = "", T)(const T id) {
		M returnModel;
		string lookupId = id.to!string;

		if (index in modelStore!M) {
			auto models = modelStore!M[index];
			if (lookupId in models) {
				returnModel = cast(M)(models[lookupId]);
			}
		}

		return returnModel;
	}

	M[] query(M, A : PersistenceAdapterInterface, T)(const T query) {
		M[] results;

		return results;
	}

	M findOne(M, string index = "", T)(const T id) { 
		M returnModel = findInStore!(M, index)(id);

		if (!returnModel) {
			// Do the adapter stuff here
		}

		return returnModel;
	}

	M[] findMany(M, string index = "", T)(const T[] ids ...) {
		M[] returnModels;
		T[] adapterSearchIds;

		foreach(id; ids) {
			auto result = findInStore!(M, index)(id);
			if (result) {
				returnModels ~= result;
			}
			else {
				adapterSearchIds ~= id;
			}
		}

		// Search the adapter;
		// Aggregate the results;
		// Inject into the store
		if (adapterSearchIds.length) {
			//auto adapterModels = ;
			//returnModels ~= adapterModels;
		}

		return returnModels;
	}

private:
	struct IndexMeta {
		string name;
		string function(ModelInterface) getKey;
	}

	static string defineModelTypes() {
		import std.string; 

		string[] typeStrings;
		foreach(A; AdapterTypes) {
			foreach(M; A.ModelTypes) {
				typeStrings ~= M.stringof;
				pragma(msg, M.stringof.color(fg.light_magenta));
			}
		}

		return "alias ModelTypes = NoDuplicates!(TypeTuple!(" ~ typeStrings.join(",") ~ "));";
	}

	static string defineModelStores() {
		string code;

		foreach(M; ModelTypes) {
			code ~= M.stringof ~ "[string][string] _" ~ M.stringof.camelCaseLower ~ "Store;";
		}

		return code;
	}

	mixin(defineModelTypes);
	mixin(defineModelStores);

	PersistenceAdapterInterface[] _adapters;
	// ModelType, Index, Id
	string delegate(ModelInterface)[string] _modelPrimaryKeyDelegate;
	IndexMeta[string] _indexMeta;
}

//version (unittest) {
	import aura.persistence.core.relations;

	class TestModelBase : ModelInterface {
		override @ignore @property string persistenceId() const { return _id; }
		override @property void persistenceId(string id) { _id = id; }
		override void ensureId() {}

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
	}

	class Adapter2 : PersistenceAdapter!(Company) {
		bool save(M)(const M model) {
			writeln("Adapter 2 is saving".color(fg.light_cyan));
			return true;
		}
	}

	class ApplicationStore : PersistenceStore!(Adapter1, Adapter2) {
	}

	alias store = ApplicationStore.instance;

	unittest {
		auto person = store.findInStore!Person("fakeId");
		assert(!person);
		person = new Person;
		person.firstName = "David";
		person.surname = "Monagle";
		person.companyReference = "aura-001";
		person.persistenceId = "1";
		store.inject(person);
		auto lookup = store.findInStore!Person("0");
		assert(!lookup);
		lookup = store.findInStore!Person("1");
		assert(lookup == person);
		
		store.addIndex!(Company, "reference");
		auto company = new Company;
		company.name = "Aura Inc";
		company.reference = "aura-001";
		company.persistenceId = "1";
		store.inject(company);
		auto lookupCompany = store.findInStore!(Company, "reference")("1");
		assert(!lookupCompany);
		lookupCompany = store.findInStore!(Company, "reference")("aura-001");
		assert(lookupCompany == company);

		auto many = store.findMany!(Company, "reference")("aura-001", "aura-002");
		assert(many.length == 1, "Expected length of 1 but got " ~ many.length.to!string);
		assert(many[0].reference == "aura-001");

		auto one = store.findOne!(Company, "reference")("aura-001");
		assert(one.reference == "aura-001");

		store.save(one);

		auto foreignCompany = person.company;
		assert(foreignCompany == company);

		assert(store.adapter!Adapter1.containerName!Company == "companies");
		store.adapter!Adapter1.containerName!Company = "kompaniez";
		assert(store.adapter!Adapter1.containerName!Company == "kompaniez");
}
//}

