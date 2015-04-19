module aura.graph.core.relationships;

import aura.graph.core.model;

import aura.util.string_transforms;
import aura.util.inflections.en;

string defineGraphBelongsTo(M, string propertyName, string key, string foreignKey)() {
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
			assert(graphInstance, "Attempted to use belongs to property '%2$s' on model '%1$s' without a graphInstance");
			%1$s returnValue;
			if (graphInstance) returnValue = graphInstance.find!%1$s("%4$s",%3$s);
			return returnValue;
		}
	`, M.stringof, _propertyName,  _key, foreignKey);
}

mixin template GraphBelongsTo(M, string propertyName = "", string key = "", string foreignKey = "") {
	mixin(defineGraphBelongsTo!(M, propertyName, key, foreignKey));
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