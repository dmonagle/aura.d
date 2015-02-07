module aura.persistence.core.relations;

// Leaving this out for the moment. Not sure it's actually good for the developer to be triggering database queries without
// explicitly requesting it. Is it such a big deal to write: auto account = store.findOne!Account(user.accountId); ??
/*
import aura.util.string_transforms;
import aura.util.inflections.en;

string defineBelongsTo(S, M, string propertyName, string key, string foreignKey)() {
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
			return %3$s.sharedInstance.findOne!(%1$s, "%5$s")(%4$s);
		}
	`, M.stringof, _propertyName, S.stringof, _key, foreignKey);
}

mixin template BelongsTo(S, M, string propertyName = "", string key = "", string foreignKey = "") {
	static if (!is(M == class)) {
		static assert(is(T : Nullable), "Belongs to type, " ~ T.stringof ~ ", must be a class or Nullable!");
	}

	mixin(defineBelongsTo!(S, M, propertyName, key, foreignKey));
}

string defineOuterBelongsTo(S, L, M, string propertyName, string key, string foreignKey)() {
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
		%1$s %2$s(%6$s model) {
			return %3$s.sharedInstance.findOne!(%1$s, "%5$s")(model.%4$s);
		}
	`, M.stringof, _propertyName, S.stringof, _key, foreignKey, L.stringof);
}

mixin template BelongsTo(S, L, M, string propertyName = "", string key = "", string foreignKey = "") {
	static if (!is(M == class)) {
		static assert(is(T : Nullable), "Belongs to type, " ~ T.stringof ~ ", must be a class or Nullable!");
	}

	mixin(defineOuterBelongsTo!(S, L, M, propertyName, key, foreignKey));
}
*/