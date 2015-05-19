module aura.graph.core.relationships;

import aura.graph.core.model;

import aura.util.string_transforms;
import aura.util.inflections.en;

public import aura.util.null_bool;

string defineGraphBelongsToProperty(M, string propertyName, string key, string foreignKey)() {
	import std.string;

	static if (!propertyName.length) 
		immutable string _propertyName = M.stringof.camelCaseLower;
	else
		immutable string _propertyName = propertyName;
	
	static if (!key.length)
		immutable string _key = _propertyName ~ "Id";
	else
		immutable string _key = key;
	
	return format(`
		@ignore @property %1$s %2$s() {
			return graphGetBelongsTo!%1$s("%3$s", %4$s);
		}
	`, M.stringof, _propertyName, foreignKey, _key);
}

mixin template GraphBelongsTo(M, string propertyName = "", string key = "", string foreignKey = "") {
	mixin(defineGraphBelongsToProperty!(M, propertyName, key, foreignKey));
}

string defineGraphOuterBelongsTo(L, M, string propertyName, string key, string foreignKey)() {
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
			assert(model.graphInstance, "Attempted to use BelongsTo property '%2$s' on model '%1$s' without a graphInstance");
			%1$s returnValue;
			if (model.graphInstance) returnValue = model.graphInstance.find!%1$s("%4$s",model.%3$s);
			return returnValue;
		}
	`, M.stringof, _propertyName, _key, foreignKey, L.stringof);
}

mixin template GraphBelongsTo(L, M, string propertyName = "", string key = "", string foreignKey = "") {
	mixin(defineGraphOuterBelongsTo!(L, M, propertyName, key, foreignKey));
}