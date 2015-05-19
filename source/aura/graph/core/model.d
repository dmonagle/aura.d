module aura.graph.core.model;

import aura.graph.core.relationships;

import aura.graph.core.graph;
import vibe.data.serialization;
public import vibe.data.serialization;

alias GraphId = string;

/*
 * Example: If the state is both dirty and deleted, then it is pending deletion
*/
struct GraphState {
	GraphId id;

	bool persisted = false;
	bool dirty = false;
	bool deleted = false;

	@property bool validId() const {
		return id.length ? true : false;
	}

	@property bool isNew() const {
		return !persisted && !deleted;
	}

	@property bool needsSync() const {
		return isNew || dirty;
	}
}

// Adds a property to a class that will return the class name at runtime. Works on base classes to return the child class type
mixin template GraphTypeProperty() {
	@ignore @property string graphType() const {
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

interface GraphStateInterface {
	/// Returns the current state of the model
	@property ref GraphState graphState();
	@property GraphState graphState() const;
	@property string graphType() const;

	final @property bool isNew() const {
		return graphState.isNew;
	}
}


interface GraphModelInterface(GraphType) : GraphStateInterface {
	alias ModelInterface = GraphModelInterface!GraphType;

	@property ref GraphType graphInstance();
	@property ref ModelInterface graphParent();

	final @property bool validGraphId() const {
		return graphState.validId;
	}
	
	final @property string graphId() const {
		return graphState.id;
	}
	
	final @property bool graphNeedsSync() const {
		return graphState.needsSync;
	}

	void graphTouch();
	void graphUntouch();
	void graphDelete();
	void graphUndelete();
}

class GraphModel(GraphType) : GraphModelInterface!GraphType {
	alias ModelInterface = GraphModelInterface!GraphType;

	mixin GraphTypeProperty;

	override @ignore @property GraphState graphState() const {
		return _graphState;
	}

	override @property ref GraphState graphState() {
		return _graphState;
	}

	override @ignore @property ref GraphType graphInstance() {
		return _graph;
	}

	override @ignore @property ref ModelInterface graphParent() {
		return _graphParent;
	}


	// Marks the model to be saved by Graph
	override void graphTouch() {
		graphState.dirty = true;
	}
	
	// Marks the model to be deleted by Graph
	override void graphDelete() {
		graphState.deleted = true;
		graphState.dirty = true;
	}
	
	// Removes the save flag from the model
	override void graphUntouch() {
		graphState.dirty = false;
	}
	
	// Removes the delete flag from the model
	override void graphUndelete() {
		graphState.deleted = false;
		graphState.dirty = true;
	}

protected:
	M graphGetBelongsTo(M, T)(string foreignKey, T value) {
		assert(graphInstance, "Attempted to use BelongsTo '" ~ M.stringof ~ "." ~ (foreignKey.length ? foreignKey : "id") ~ "' without a graphInstance");

		M returnValue;
		if (isNotNull(value)) returnValue = graphInstance.find!M(foreignKey, value);
		return returnValue;
	}

	M graphGetBelongsTo(M, T)(T value) {
		return graphGetBelongsTo!M("", value);
	}

private:
	GraphState _graphState;

	GraphType _graph;
	ModelInterface _graphParent;
}