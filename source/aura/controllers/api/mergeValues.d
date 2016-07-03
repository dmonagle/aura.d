/**
    This, along with a serializer framework needs to be moved into a module
    probably the graph module
*/
module aura.controllers.api.mergeValues;

import aura.api.serializers.rest;
import aura.graph.value;
import aura.graph.model;
import aura.data.json;

void mergeValues(S : RestApiModelSerializerInterface, M : GraphModelInterface, T)(RestApiSerializer serializer, M model, T updates) {
    auto modelSerializer = serializer.modelSerializer!(M, S);
    auto filteredUpdates = modelSerializer.filter(updates);
    model.merge(filteredUpdates);
}
