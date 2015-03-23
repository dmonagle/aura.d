module aura.persistence.core.model;

import aura.persistence.core;
import aura.util.null_bool;
public import vibe.data.serialization;

interface ModelInterface {
	@ignore @property string persistenceId() const;
	@property void persistenceId(string id);
	@ignore @property string persistenceType() const;
	@ignore @property bool isNew() const;
	void ensureId();
}

// Adds a property to a class that will return the class name at runtime. Works on base classes to return the child class type
mixin template PersistenceTypeProperty() {
	@ignore @property string persistenceType() const {
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

import std.typetuple;

/// Calls the given action on every class or struct with the @embedded UDA
void ensureEmbedded(alias action, M)(ref M model) {
	foreach (memberName; __traits(allMembers, M)) {
		static if (is(typeof(__traits(getMember, model, memberName)))) {
			static if (__traits(getProtection, __traits(getMember, model, memberName)) == "public") {
				alias member = TypeTuple!(__traits(getMember, M, memberName));
				alias embeddedUDA = findFirstUDA!(EmbeddedAttribute, member);
				static if (embeddedUDA.found) {
					auto embeddedModel = __traits(getMember, model, memberName);
					if (embeddedModel.isNotNull) {
						static if (isArray!(typeof(embeddedModel))) {
							foreach(ref m; embeddedModel) {
								action(m); // Run the action on each item in the array
								ensureEmbedded!action(m); // Ensure recursive
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

