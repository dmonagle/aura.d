module aura.graph.resolve;

import aura.graph;


interface GraphResolverInterface {
	bool resolved() const;
	void resolve(bool force);
}

class GraphResolver(T) : GraphResolverInterface {
    alias ResolverDelegate = T delegate(); 

    this(ResolverDelegate resolver) {
        _resolver = resolver;
    }

	bool resolved() const { return _value ? true : false; }
	void resolve(bool force = false) {
        if (!resolved || force) _value = _resolver(); 
    }
	
	@property T value() {
        resolve;
		return _value;
    }
    
	@property void value(T newValue) {
        _value = newValue;
    }
	
	alias value this;
	
private:
	T _value;
    ResolverDelegate _resolver;
}

class GraphBelongsToResolver(P : GraphModelInterface, M : GraphModelInterface, string key, string foreignKey) : GraphResolverInterface {
    this(P model) {
        _parent = model;
    }

	bool resolved() const { return _model ? true : false; }
	void resolve(bool force = false) {
        auto lookupValue = __traits(getMember, _parent, key);
        if (!resolved || force) _model = _parent.graph.find!(M, foreignKey)(lookupValue); 
    }
	
	@property M value() {
        resolve;
		return _model;
    }
    
	@property void value(M newValue) {
        _model = newValue;
        __traits(getMember, _parent, key) = __traits(getMember, _model, foreignKey);
    }
	
	alias value this;
	
private:
    P _parent; // References the parent model that the resolver resides in
	M _model;
}

// version (unittest) {
// 	class GraphTestUser : GraphModelInterface {
// 		mixin GraphModelImplementation;
		
// 		string id;
// 		string name;
//         string bestFriendId;

// 		override @property string graphId() const { return id; }
// 		override @property void graphId(string newId) { id = newId; }
        
//         private alias BestFriendResolver  = GraphBelongsToResolver!(GraphTestUser, GraphTestUser, "bestFriendId", "id");
//         private BestFriendResolver _bestFriendResolver; 
//         @ignore @property BestFriendResolver bestFriend() {
//             if (!_bestFriendResolver)  _bestFriendResolver = new BestFriendResolver(this);
//             return _bestFriendResolver; 
//         }
// 	}
	
// 	unittest {
//         auto graph = new Graph;
        
// 		auto david = graph.inject(new GraphTestUser);
//         david.id = "0";
// 		david.name = "David";

// 		auto mia = graph.inject(new GraphTestUser);
//         mia.id = "1";
// 		mia.name = "Mia";
// 		mia.bestFriendId = "0";

//         assert(mia.bestFriend);
//         assert(mia.bestFriend.name == "David");
// 	}
	
// 	unittest {
//         auto graph = new Graph;
        
// 		auto david = graph.inject(new GraphTestUser);
//         david.id = "0";
// 		david.name = "David";

// 		auto mia = graph.inject(new GraphTestUser);
//         mia.id = "1";
// 		mia.name = "Mia";

//         mia.bestFriend.value = david;
//         assert(mia.bestFriendId == "0");
// 	}
// }
