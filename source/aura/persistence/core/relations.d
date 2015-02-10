module aura.persistence.core.relations;

// Leaving this out for the moment. Not sure it's actually good for the developer to be triggering database queries without
// explicitly requesting it. Is it such a big deal to write: auto account = store.findOne!Account(user.accountId); ??

import aura.util.string_transforms;
import aura.util.inflections.en;

string defineBelongsTo(M, string propertyName, string key, string foreignKey)() {
	import std.string;
	
	static if (!propertyName.length) 
		string _propertyName = M.stringof.camelCaseLower;
	else
		string _propertyName = propertyName;

	static if (!key.length)
		string _key = _propertyName ~ "Id";
	else
		string _key = key;

	return format(`
		@ignore @property %1$s %2$s() {
			assert(persistenceStore, "persistenceStore for model was not set when looking up BelongsTo(%1$s)");
			return persistenceStore.findOne!(%1$s, "%4$s")(%3$s);
		}
	`, M.stringof, _propertyName, _key, foreignKey);
}

mixin template BelongsTo(M, string propertyName = "", string key = "", string foreignKey = "") {
	static assert (__traits(hasMember, M, "persistenceStore"), "Cannot use mixin BelongsTo on model '" ~ M.stringof ~ "' as it does not implement the persistenceStore property. Perhaps use the PersistenceStoreProperty mixin?");
	static if (!is(M == class)) {
		static assert(is(T : Nullable), "Belongs to type, " ~ T.stringof ~ ", must be a class or Nullable!");
	}

	mixin(defineBelongsTo!(M, propertyName, key, foreignKey));
}

string defineOuterBelongsTo(L, M, string propertyName, string key, string foreignKey)() {
	import std.string;
	
	static if (!propertyName.length) 
		string _propertyName = M.stringof.camelCaseLower;
	else
		string _propertyName = propertyName;
	
	static if (!key.length)
		string _key = _propertyName ~ "Id";
	else
		string _key = key;
	
	return format(`
		%1$s %2$s(%5$s model) {
			assert(model.persistenceStore, "persistenceStore for model was not set when looking up BelongsTo(%1$s)");
			return model.persistenceStore.findOne!(%1$s, "%4$s")(model.%3$s);
		}
	`, M.stringof, _propertyName, _key, foreignKey, L.stringof);
}

mixin template BelongsTo(L, M, string propertyName = "", string key = "", string foreignKey = "") {
	static assert (__traits(hasMember, M, "persistenceStore"), "Cannot use mixin BelongsTo on model '" ~ M.stringof ~ "' as it does not implement the persistenceStore property. Perhaps use the PersistenceStoreProperty mixin?");
	static if (!is(M == class)) {
		static assert(is(T : Nullable), "Belongs to type, " ~ T.stringof ~ ", must be a class or Nullable!");
	}

	mixin(defineOuterBelongsTo!(L, M, propertyName, key, foreignKey));
}
