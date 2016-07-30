module aura.api.serializers.filter;

import aura.graph;
import aura.data.json;
import aura.data.attribute_tree;

import std.array;
import std.algorithm;

interface SerializerFilterInterface {
    @property GraphModelInterface context();
    GraphValue filter(GraphValue source);
    void reset(); 
}

class SerializerFilter : SerializerFilterInterface {
    @property GraphModelInterface context() { return _context; }
    GraphValue filter(GraphValue source) {
        return GraphValue(GraphValue.emptyObject);
    }
    
    void reset() {
    }

protected:
    AttributeTree _filters;
    bool _whitelist; 
    GraphModelInterface _context;
}

unittest {
    auto f = new SerializerFilter();
    assert(false);
}