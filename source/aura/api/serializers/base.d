module aura.api.serializers.base;

import aura.graph;
import aura.data.json;

import std.array;
import std.algorithm;

interface ApiSerializerInterface 
{
    @property ApiSerializerInterface root();

    @property ApiSerializerInterface parent();
    @property void parent(ApiSerializerInterface);

    @property GraphModelInterface context();
    
    @property bool preparedForSerialization();
    @property void preparedForSerialization(bool);
    
    void prepareForSerialization();
    GraphValue serialize();
}

mixin template PreparedForSerializationImplementation() {
}

class BaseApiSerializer {
    /// Returns the topmost serializer in the tree
    @property BaseApiSerializer root()
    {
        if (!_parent) {
            auto r = cast(BaseApiSerializer)this;
            assert(r, "No root Api controller found in chain!");
            return r;
        }
        return _parent.root;
    }

    string keyFor(string modelName) { return modelName; }
    string keyFor(M : GraphModelInterface)() { return keyFor(M.string); }

    @property BaseApiSerializer parent() { return _parent; }
    @property void parent(BaseApiSerializer value) { _parent = value; }

    @property bool preparedForSerialization() { return _preparedForSerialization; }
    @property void preparedForSerialization(bool value) { _preparedForSerialization = value; }
    
    void prepareForSerialization() { preparedForSerialization = true; }
    GraphValue serialize() { return GraphValue.emptyObject; }

protected:
    BaseApiSerializer _parent;
    bool _preparedForSerialization;
}
