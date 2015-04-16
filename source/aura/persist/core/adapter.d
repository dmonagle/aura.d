module aura.persist.core.adapter;

import aura.persist.core.model;

interface PersistAdapterInterface {
	void ensureId(PersistModelInterface model) const;
	bool save(PersistModelInterface model) const;
}
