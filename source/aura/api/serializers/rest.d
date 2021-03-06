module aura.api.serializers.rest;

import aura.api.serializers.base;
import aura.graph.value;
import aura.graph.model;

import std.array;
import std.algorithm;

alias AttributeTree = aura.data.attribute_tree.AttributeTree;

class RestApiSerializer : BaseApiSerializer 
{
    mixin GraphModelStoreImplementation;
    
    @property GraphModelInterface context() { return _context; }
    @property void context(GraphModelInterface value) { _context = value; }

    this() {
    }

    this(GraphModelInterface context) {
        this.context = context; 
    }

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

    auto addModel(M : GraphModelInterface)(M model) 
    in {
        assert(model, "Attempted to add null " ~ M.stringof ~ " to serializer");
    } 
    body {
        if (!modelCount) makePrimary!M; // If this is the first model added, make it the primary type
        auto s = modelSerializer!M;
        assert(s, "attempt to add models but no ApiModelSerializer has been set for type: " ~ M.stringof);
        if (modelStore!M.addUnique(model)) 
            s.preparedForSerialization = false;
        return s;
    }

    void addModels(M : GraphModelInterface)(M[] models) {
        foreach(model; models) addModel!M(model);
    } 

    auto addModel(S : BaseApiSerializer, M : GraphModelInterface)(M model)
    in {
        assert(model, "Attempted to add null " ~ M.stringof ~ " to serializer: " ~ S.stringof);
    } 
    body {
        auto s = modelSerializer!(M, S);
        // This could just defer to the above
        if (modelStore!M.addUnique(model))
            s.preparedForSerialization = false;
        return s;
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
                assert(serializer.preparedForSerialization, "Serializer not prepared for serialization: " ~ typeid(serializer).toString);
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
// unittest {

//     auto s1 = new RestApiSerializer;
//     auto s2 = new ApiSerializer;
//     auto s3 = new ApiSerializer;
    
//     s2.parent = s1;
//     s3.parent = s2;
    
//     assert(!s1.parent, "s1 should have no parent");
//     assert(s1.root == s1);
//     assert(s2.parent == s1);
//     assert(s2.root == s1);
//     assert(s3.parent == s2);
//     assert(s3.root == s1);
    
//     assert(s1.primaryType == "");
// }

interface RestApiModelSerializerInterface {
    @property GraphModelInterface model();
    @property void model(GraphModelInterface);
}

class RestApiModelSerializer(M : GraphModelInterface) : BaseApiSerializer, RestApiModelSerializerInterface {
    /// This can be overridden to define filters for child classes
    void defineFilters() 
	in {
		assert(model, "defineFilters called with no model set");
	} 
    body {
        resetFilters;
    }

    @property ref accessWhiteList() { return _accessWhiteList; }
    @property ref updateWhiteList() { return _updateWhiteList; }

	@property AttributeTree updateFilter() {
        if (!_updateAttributes) _updateAttributes = new AttributeTree;  
        return _updateAttributes; 
    }
    
	@property AttributeTree accessFilter() {
        if (!_accessAttributes) _accessAttributes = new AttributeTree;  
        return _accessAttributes; 
    }
    
    @property RestApiSerializer restSerializer() {
        return cast(RestApiSerializer)root;
    }
    
    @property GraphModelInterface context() { return restSerializer.context; }
	
    @property M model() { return _model; }
    @property void model(GraphModelInterface value) { 
        _model = cast(M)value; 
        resetFilters; 
    }
    
    /// Returns the model store from the root api serializer for this model
    @property auto modelStore() { return (cast(RestApiSerializer)root).modelStore!M; }

    /// Returns a GraphValue of the given value with the access filters applied
	GraphValue filterAccess(T)(T value, bool initFilters = true) {
        if (initFilters) defineFilters;
        static if (is(T == GraphValue)) 
            alias gValue = value;
        else  
            auto gValue = toGraphValue(value);

        
		if (_accessWhiteList) 
			return gValue.filterIn(_accessAttributes);
		else 
			return gValue.filterOut(_accessAttributes);
		
	}
	
	/// Returns a GraphvValue of the given value with the update filters applied, ie: only fields updatable should be included
	GraphValue filterUpdate(T)(T value, bool initFilters = true) {
        if (initFilters) defineFilters;
        static if (is(T == GraphValue)) 
            alias gValue = value;
        else  
            auto gValue = toGraphValue(value);

		if (_updateWhiteList)
			return gValue.filterIn(_updateAttributes);
		else			
			return gValue.filterOut(_updateAttributes);
	}

	/// Returns a GraphValue of the given value with both the update and the access filters applied, ie: only fields updatable and accessible by the context should be included
	GraphValue filter(T)(T value) 
    in {
        assert(model, "ModelSerializer filter was called but no model has been set");
    } 
    body {
        defineFilters;
        return filterUpdate(filterAccess(value, false), false);
	}
    
	/// Prepare the model for serialization
	GraphValue serializeModel() {
		if (!model) return GraphValue(null);
		return (cast(M)model).serializeToGraphValue;
	}
	
    /// The final serialized value
	override GraphValue serialize() {
		auto value = serializeModel();

        defineFilters;
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
	void resetFilters() {
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