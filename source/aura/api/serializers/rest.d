module aura.api.serializers.rest;

import aura.api.serializers.base;
import aura.graph;
import aura.data.json;

import aura.data.json;
import aura.graph.model;

import std.array;
import std.algorithm;

alias AttributeTree = aura.data.attribute_tree.AttributeTree;

class RestApiSerializer : BaseApiSerializer 
{
    mixin GraphModelStoreImplementation;
    
    @property GraphModelInterface context() { return _context; }
    @property void context(GraphModelInterface value) { _context = value; }

    auto modelSerializer(M : GraphModelInterface, S : BaseApiSerializer)() 
    {
        if (M.stringof !in _modelSerializers) {
            auto s = new S(); 
            s.parent = this;
            _modelSerializers[M.stringof] = s;
        }
        
        auto returnValue = cast(S)_modelSerializers[M.stringof];
        assert(returnValue, "Could not retrieve serializer, possibly it's being cast incorrectly");
        return returnValue;
    } 
    
    auto modelSerializer(M : GraphModelInterface)() 
    {
        return modelSerializer(M.stringof);
    }
    
    auto modelSerializer(string modelType) {
        if (modelType in _modelSerializers) return _modelSerializers[modelType];
        return cast(BaseApiSerializer)null;
    } 

    void addModel(M : GraphModelInterface)(M model) 
    {
        if (!modelCount) makePrimary!M; // If this is the first model added, make it the primary type
        auto s = modelSerializer!M;
        if (modelStore!M.addUnique(model)) 
            s.preparedForSerialization = false;
    }

    void addModels(M : GraphModelInterface)(M[] models) {
        foreach(model; models) addModel!M(model);
    } 

    void addModel(S : BaseApiSerializer, M : GraphModelInterface)(M model) 
    {
        auto s = modelSerializer!(M, S);
        // This could just defer to the above
        if (modelStore!M.addUnique(model))
            s.preparedForSerialization = false;
    }
    
    void addModels(S : BaseApiSerializer, M : GraphModelInterface)(M[] models) {
        foreach(model; models) addModel!(S,M)(model);
    } 
        
    void makePrimary(string modelType) {
        _primaryType = modelType;
    }

    void makePrimary(M : GraphModelInterface)() {
        makePrimary(M.stringof);
    }
    
    @property string primaryType() inout {
        return _primaryType;
    }
    
    override GraphValue serialize() {
        auto unprepared = array(_modelSerializers.values.filter!((s) => !s.preparedForSerialization));
        while (unprepared.length) {
            foreach(s; unprepared) {
                s.preSerialization;
                assert(s.preparedForSerialization, "Serializer not prepared for serialization right after preSerialization was called");
            }
            unprepared = array(_modelSerializers.values.filter!((s) => !s.preparedForSerialization));
        }

        auto value = GraphValue.emptyObject;
        foreach(string modelType, store; _graphModelStores) {
            auto serializer = modelSerializer(modelType);
            assert(serializer, "No serializer loaded for modelType: " ~ modelType);

            if (auto modelSerializer = cast(RestApiModelSerializerInterface)serializer) {
                GraphValue.Array serializedModels;
                foreach(model; store) {
                    modelSerializer.model = model;
                    serializedModels ~= serializer.serialize; 
                }
                value[keyFor(modelType)] = GraphValue(serializedModels);
            }
        }
        
        return value;
    }

private:
    BaseApiSerializer[string] _modelSerializers;
    GraphModelInterface _context;
    string _primaryType;

}

// Test the parent and root attributes
unittest {

    auto s1 = new RestApiSerializer;
    auto s2 = new ApiSerializer;
    auto s3 = new ApiSerializer;
    
    s2.parent = s1;
    s3.parent = s2;
    
    assert(!s1.parent, "s1 should have no parent");
    assert(s1.root == s1);
    assert(s2.parent == s1);
    assert(s2.root == s1);
    assert(s3.parent == s2);
    assert(s3.root == s1);
    
    assert(s1.primaryType == "");
}

interface RestApiModelSerializerInterface {
    @property GraphModelInterface model();
    @property void model(GraphModelInterface value);
}

class RestApiModelSerializer(M : GraphModelInterface) : BaseApiSerializer, RestApiModelSerializerInterface {
	void filter() {}
	
	@property AttributeTree updateFilter() { 
        assert(_updateAttributes, "updateFilter called before reset()");
        return _updateAttributes; 
    }
    
	@property AttributeTree accessFilter() {
        assert(_accessAttributes, "accessFilter called before reset()");
        return _accessAttributes; 
    }
    
    @property RestApiSerializer restSerializer() {
        return cast(RestApiSerializer)root;
    }
    
    @property GraphModelInterface context() { return restSerializer.context; }
	
    @property M model() { return _model; }
    @property void model(GraphModelInterface value) { _model = cast(M)value; reset; }
    
    /// Returns the model store from the root api serializer for this model
    @property auto modelStore() { return (cast(RestApiSerializer)root).modelStore!M; }

    /// Returns a copy of the given json with the access filters applied
	GraphValue filterAccess(GraphValue value) {
		if (_accessWhiteList) 
			return value.filterIn(_accessAttributes);
		else 
			return value.filterOut(_accessAttributes);
		
	}
	
	/// Returns a copy of the given json with the update filters applied, ie: only fields updatable should be included
	GraphValue filterUpdate(GraphValue value) {
		if (_updateWhiteList)
			return value.filterIn(_updateAttributes);
		else			
			return value.filterOut(_updateAttributes);
	}

	/// Returns a copy of the given json with both the update and the access filters applied, ie: only fields updatable and accessible by the context should be included
	GraphValue filter(GraphValue value) {
        return filterUpdate(filterAccess(value));
	}
    
	/// Prepare the model for serialization
	GraphValue serializeModel() {
		if (!model) return GraphValue(null);
		return (cast(M)model).serializeToGraphValue;
	}
	
    /// The final serialized value
	override GraphValue serialize() {
		auto value = serializeModel();

		value = filterAccess(value);

		if(_updateAttributes.hasChildren) {
            GraphValue.Array paths;
            foreach(path; _updateAttributes.leafPaths) paths ~= GraphValue(path);
			if (_updateWhiteList)
				value["_updateable"] = GraphValue(paths);
			else			
				 value["_readOnly"] = GraphValue(paths);
		}

		return value;
	}

protected: 
	void reset() {
		_accessAttributes = new AttributeTree;
		_updateAttributes = new AttributeTree;
	}
private:
    M _model;
    
	bool _accessWhiteList;
	bool _updateWhiteList;

	AttributeTree _updateAttributes;
	AttributeTree _accessAttributes;
}

/*
version (unittest) {
	struct TestJob {
		string title;
		@optional int level;
	}
	
	class TestUser {
		string firstName;
		@optional string surname;
		@optional string title;
		int salary;
		@optional TestJob job;
	}
	
	class TestUserSerializer : RestApiModelSerializer!(TestUser, TestUser) {
		override void filter() {
			accessFilter.add("salary", "job.title");
			updateFilter.add("firstName", "surname", "job.level");
		}
	}

	unittest {
		import std.stdio;
		import colorize;
		import aura.data.json.convenience;
		
		auto user = new TestUser;
		user.firstName = "John";
		user.surname = "Smith";
		user.job.title = "Timelord";
		user.salary = 100000;

		auto s = new TestUserSerializer;
		s.data = user;
		s.context = user;

		auto serialized = s.serialize;
		writeln(serialized.toPrettyString.color(fg.light_blue));

		assert(isObject(serialized));
		auto readOnly = serialized["_readOnly"];
		assert(isArray(readOnly));
	}
}
*/