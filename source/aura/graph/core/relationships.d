module aura.graph.core.relationships;

import aura.graph.core;

interface GraphRelationship {
	bool resolved() const;
	void resolve(bool force);
}

class GraphBelongsTo(M : GraphModelInterface) : GraphRelationship {
	this() {
	}

	this(M relation) {
		_relation = relation;
	}

	bool resolved() const { return _relation ? true : false; }
	void resolve(bool force) {}
	
	@property M relation() {
		return _relation;
	}
	
	void opAssign(M model) { _relation = model; }
	
	alias relation this;
	
private:
	M _relation;
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
		GraphBelongsTo!GraphTestUser belongsTo;
		belongsTo = new GraphBelongsTo!GraphTestUser;
		assert(!belongsTo.resolved);

		auto user = new GraphTestUser;
		user.name = "David";

		belongsTo = user;

		assert(belongsTo.resolved);
		assert(belongsTo.name == "David");
	}
	
}
