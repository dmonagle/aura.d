module aura.persist.core.model;

import aura.persist.core.graph;
import vibe.data.serialization;

alias PersistId = string;

/*
 * Example: If the state is both dirty and deleted, then it is pending deletion
*/
struct PersistState {
	PersistId id;

	bool persisted = false;
	bool dirty = false;
	bool deleted = false;

	@property bool validId() const {
		return id.length ? true : false;
	}
}

// Adds a property to a class that will return the class name at runtime. Works on base classes to return the child class type
mixin template PersistTypeProperty() {
	@ignore @property string persistType() const {
		import std.string;
		import std.regex;
		
		auto constMatch = ctRegex!`^const\((.*)\)$`;
		auto typeString = typeid(this).toString();
		
		if (auto matches = typeString.matchFirst(constMatch)) {
			typeString = matches[1];
		}
		
		return typeString.split(".")[$ - 1];
	}
}

interface PersistModelInterface {
	/// Returns the current state of the model
	@property PersistState persistState() const;
	@property ref PersistState persistState();
	@property GraphInterface graphInterface();

	@property string persistType() const;
	final @property bool isNew() const {
		return !persistState.persisted;
	}
}

class PersistModel : PersistModelInterface {
	mixin PersistTypeProperty;

	override @property PersistState persistState() const {
		return _persistState;
	}

	override @property ref PersistState persistState() {
		return _persistState;
	}

	override @property GraphInterface graphInterface() {
		return _graph;
	}

private:
	PersistState _persistState;
	GraphInterface _graph;
}

unittest {
	PersistModel model = new PersistModel;
	assert(PersistModel.stringof == model.persistType);
	assert(model.isNew);
	assert(!model.persistState.persisted);
	model.persistState.persisted = true;
	assert(!model.isNew);
	assert(model.persistState.persisted);
	assert(model.persistType == "PersistModel");
}