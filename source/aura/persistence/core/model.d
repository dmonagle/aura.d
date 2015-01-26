module aura.persistence.core.model;

import aura.persistence.core.store;
import vibe.data.serialization;

interface ModelInterface {
	@ignore @property string persistenceId() const;
	@property void persistenceId(string id);
	void ensureId();
}
