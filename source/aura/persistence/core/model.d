module aura.persistence.core.model;

import aura.persistence.core;
import aura.util.null_bool;
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

import std.typetuple;

/// Calls the given action on every ModelInterface with an embedded UDA
void ensureEmbedded(alias action, M)(ref M model) {
	foreach (memberName; __traits(allMembers, M)) {
		static if (is(typeof(__traits(getMember, model, memberName)) : ModelInterface)) {
			static if (__traits(getProtection, __traits(getMember, model, memberName)) == "public") {
				alias member = TypeTuple!(__traits(getMember, M, memberName));
				alias embeddedUDA = findFirstUDA!(EmbeddedAttribute, member);
				static if (embeddedUDA.found) {
					auto embeddedModel = __traits(getMember, model, memberName);
					if (embeddedModel.isNotNull) {
						static if (isArray!(typeof(embeddedModel))) {
							foreach(ref m; embeddedModel) {
								action(m); // Run the action on each item in the array
								ensureEmbedded!M(m, action); // Ensure any recursive Ids
							}
						} else {
							action(embeddedModel);
							ensureEmbedded!action(embeddedModel);
						}
					}
				}
			}
		}
	}
}

