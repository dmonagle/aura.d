module aura.graph.relationships;

import aura.graph;
import transforms;
import inflections.en;


string defineGraphBelongsToProperty(P : GraphModelInterface, M : GraphModelInterface, string propertyName, string key, string foreignKey)() {
	import std.format;
	
	static if (!propertyName.length) 
		enum _propertyName = M.stringof.camelCaseLower;
	else
		enum _propertyName = propertyName;
	
	static if (!key.length)
		enum _key = _propertyName ~ "Id";
	else
		enum _key = key;
        
    enum _resolverTypeName = _propertyName.camelCaseUpper ~ "Resolver";
    enum _resolverName = "_" ~ _propertyName ~ "Resolver";
	
	return format(`
        private alias %6$s = GraphBelongsToResolver!(%1$s, %2$s, "%4$s", "%5$s");
        private %6$s %7$s; 
        %6$s %3$s(string file = __FILE__, typeof(__LINE__) line = __LINE__) {
			enforce(graph, "Attempted to use GraphBelongsTo property '%3$s(%2$s)' on model '%1$s' without a graph instance %%s(%%s)", file, line);
            if (!%7$s) %7$s = new %6$s(this);
            return %7$s; 
        }
	`, P.stringof, M.stringof, _propertyName, _key, foreignKey, _resolverTypeName, _resolverName);
}

mixin template GraphBelongsTo(P : GraphModelInterface, M : GraphModelInterface, string propertyName = "", string key = "", string foreignKey = "_id") {
	mixin(defineGraphBelongsToProperty!(P, M, propertyName, key, foreignKey));
}

/*
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
		@ignore @property %1$s %2$s(string file = __FILE__, typeof(__LINE__) line = __LINE__) {
			enforce(graph, "Attempted to use GraphBelongsTo property '%2$s(%1$s)' on model '" ~ graphType ~ "' without a graph instance", file, line);
			return graph.find!(%1$s, "%3$s")(%4$s);
		}
	`, M.stringof, _propertyName, foreignKey, _key);
}

mixin template GraphBelongsTo(M, string propertyName = "", string key = "", string foreignKey = "_id") {
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
			assert(model.graph, "Attempted to use BelongsTo property '%2$s' on model '%1$s' without a graph");
			%1$s returnValue;
			if (model.graph) returnValue = model.graph.find!(%1$s,"%4$s")(model.%3$s);
			return returnValue;
		}
	`, M.stringof, _propertyName, _key, foreignKey, L.stringof);
}

mixin template GraphBelongsTo(L, M, string propertyName = "", string key = "", string foreignKey = "_id") {
	mixin(defineGraphOuterBelongsTo!(L, M, propertyName, key, foreignKey));
}

*/

version (unittest) {
	class GraphTestUser : GraphModelInterface {
		mixin GraphModelImplementation;
		
		string id;
		string name;
        string bestFriendId;

		override @property string graphId() const { return id; }
		override @property void graphId(string newId) { id = newId; }
        
        mixin GraphBelongsTo!(GraphTestUser, GraphTestUser, "bestFriend", "bestFriendId", "id");        
	}
	
	unittest {
        auto graph = new Graph;
        
		auto david = graph.inject(new GraphTestUser);
        david.id = "0";
		david.name = "David";

		auto mia = graph.inject(new GraphTestUser);
        mia.id = "1";
		mia.name = "Mia";
		mia.bestFriendId = "0";

        assert(!mia.bestFriend.resolved);
        assert(mia.bestFriend.name == "David");
        assert(mia.bestFriend.resolved);
	}
	
	unittest {
        auto graph = new Graph;
        
		auto david = graph.inject(new GraphTestUser);
        david.id = "0";
		david.name = "David";

		auto mia = graph.inject(new GraphTestUser);
        mia.id = "1";
		mia.name = "Mia";

        mia.bestFriend.value = david;
        assert(mia.bestFriendId == "0");
	}
}
