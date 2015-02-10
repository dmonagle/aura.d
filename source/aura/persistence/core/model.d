module aura.persistence.core.model;

import aura.persistence.core.store;
import vibe.data.serialization;

interface ModelInterface {
	@ignore @property string persistenceId() const;
	@property void persistenceId(string id);
	@ignore @property string persistenceType() const;
	void ensureId();
	//@ignore @property StoreType store();

}

mixin template PersistenceTypeProperty() {
	@ignore @property string persistenceType() const {
		import std.string;
		return typeid(this).toString().split(".")[$ - 1];
	}
}

mixin template PersistenceStoreProperty(S) {
	alias PersistenceStoreType = S;

	@property S persistenceStore() { 
		return _persistenceStore; 
	}

	@property void persistenceStore(S s) { 
		_persistenceStore = s; 
	}

private:
	S _persistenceStore;
}
