module aura.persist.core.model;

alias PersistId = string;

/*
 * Example: If the state is both dirty and deleted, then it is pending deletion
*/
struct PersistState {
	PersistId id;
	bool persisted = false;
	bool dirty = false;
	bool deleted = false;
}

interface PersistModelInterface {
	/// Returns the current state of the model
	@property const ref PersistState persistState() const;
	@property ref PersistState persistState();

	@ignore @property string persistenceType() const;
	@ignore @property bool isNew() const;
}

class PersistModel {
	override @property const ref PersistState persistState() const {
		return _persistState;
	}
	
	override @property ref PersistState persistState() {
		return _persistState;
	}

	override @property bool isNew() const {
		return !persistState.persisted;
	}
	
private:
	PersistState _persistState;
}

unittest {
	PersistModel model = new PersistModel;

	assert(model.isNew);
}