module aura.graph.core.embedded;

import aura.util.traits;
import aura.util.null_bool;

import std.typetuple;

struct GraphEmbeddedAttribute {
}

@property GraphEmbeddedAttribute graphEmbedded() { return GraphEmbeddedAttribute(); }

/// Calls the given action on every class or struct with the @graphEmbedded UDA
void eachEmbeddedGraph(alias action, M)(ref M model) {
	foreach (memberName; __traits(allMembers, M)) {
		static if (is(typeof(__traits(getMember, model, memberName)))) {
			static if (__traits(getProtection, __traits(getMember, model, memberName)) == "public") {
				alias member = TypeTuple!(__traits(getMember, M, memberName));
				alias embeddedUDA = findFirstUDA!(GraphEmbeddedAttribute, member);
				static if (embeddedUDA.found) {
					auto embeddedModel = __traits(getMember, model, memberName);
					if (embeddedModel.isNotNull) {
						static if (isArray!(typeof(embeddedModel))) {
							foreach(ref arrayModel; embeddedModel) {
								action(arrayModel, model); // Run the action on each item in the array
								eachEmbeddedGraph!action(arrayModel); // recursive call for children
							}
						} else {
							action(embeddedModel, model);
							eachEmbeddedGraph!action(embeddedModel);
						}
					}
				}
			}
		}
	}
}