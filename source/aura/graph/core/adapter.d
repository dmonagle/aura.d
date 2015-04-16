module aura.persist.core.adapter;

import aura.persist.core.model;
import vibe.data.bson;

interface PersistAdapterInterface {
	string containerName(string modelType) const;
	void ensureId(PersistModelInterface model) const;
	bool save(PersistModelInterface model) const;
}

class PersistAdapter : PersistAdapterInterface {
	override string containerName(string modelType) const {
		import aura.util.string_transforms;
		import aura.util.inflections.en;

		return modelType.snakeCase.pluralize;
	}

	override void ensureId(PersistModelInterface model) const {
		if (!model.persistState.validId) model.persistState.id = BsonObjectID.generate.toString;
	}

	override bool save(PersistModelInterface model) const {
		return false;
	}
}


unittest {
	PersistModel model = new PersistModel;
	PersistAdapter adapter = new PersistAdapter;

	assert(!model.persistState.validId);
	adapter.ensureId(model);
	assert(model.persistState.validId);
}