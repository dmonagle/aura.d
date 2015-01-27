module aura.persistence.core.model;

import aura.persistence.core.store;
import vibe.data.serialization;

interface ModelInterface {
	@ignore @property string persistenceId() const;
	@property void persistenceId(string id);
	@ignore @property string persistenceType() const;
	void ensureId();
}

mixin template PersistenceTypeMixin() {
	@ignore @property string persistenceType() const {
		import std.string;
		return typeid(this).toString().split(".")[$ - 1];
	}
}
