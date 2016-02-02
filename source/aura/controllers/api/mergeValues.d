///
module aura.controllers.api.mergeValues;

import graph.core.model;
import graph.value;
import aura.data.json;

/// Merges the JSON updates with the given model, via the serializer
void mergeValues(S, C, M)(S serializer, M model, Json updates, C serializerContext) {
    updates = serializer.jsonFilter(updates);
    model.merge(updates);
}

/// ditto
void mergeValues(S, C, M)(M model, Json updates, C serializerContext) {
    auto serializer = new S(serializerContext, model);
    mergeValues(serializer, model, updates, serializerContext);
}