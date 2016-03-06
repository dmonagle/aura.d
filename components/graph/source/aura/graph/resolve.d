module aura.graph.resolve;

import aura.graph;


interface GraphResolverInterface {
	bool resolved() const;
	void resolve(bool force);
}

class GraphResolver(T) : GraphResolverInterface {
    alias ResolverDelegate = T delegate(); 
	this() {
	}
    
    this(ResolverDelegate resolver) {
        _resolver = resolver;
    }

	this(T value) {
		_value = value;
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

version (unittest) {
	class GraphTestUser : GraphModelInterface {
		mixin GraphModelImplementation;
		
		string id;
		string name;

		override @property string graphId() const { return id; }
		override @property void graphId(string newId) { id = newId; }
	}
	
	unittest {
        alias TestResolve = GraphResolver!(GraphTestUser); 
		auto belongsTo = new TestResolve;
		assert(!belongsTo.resolved);

		auto user = new GraphTestUser;
		user.name = "David";

		belongsTo = user;

		assert(belongsTo.resolved);
		assert(belongsTo.name == "David");
	}
	
}