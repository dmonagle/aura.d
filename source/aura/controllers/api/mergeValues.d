/**
    This, along with a serializer framework needs to be moved into a module
    probably the graph module
*/
module aura.controllers.api.mergeValues;

import aura.api.serializers.rest;
import aura.graph.value;
import aura.graph.model;
import aura.data.json;

/// Adds the model to the RestApiSerializer and merges in the given Json values
void mergeValues(S : RestApiModelSerializerInterface, M : GraphModelInterface, T)(RestApiSerializer restSerializer, M model, T updates) 
in {
    assert(model);
}
body {
    restSerializer.addModel!S(model);
    auto modelSerializer = restSerializer.modelSerializer!(M, S);
    assert(modelSerializer);
    modelSerializer.model = model;
    auto filteredUpdates = modelSerializer.filter(updates);
    model.merge(filteredUpdates);
}
