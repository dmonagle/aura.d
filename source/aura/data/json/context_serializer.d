module aura.data.json.context_serializer;

import aura.data.json;
import aura.data.attribute_tree;

interface ContextSerializerInterface {
	Json toJson();
	@property AttributeTree accessFilter();
	@property AttributeTree updateFilter();
}

class ContextSerializer(C, D) : ContextSerializerInterface {
	alias ContextType = C;
	alias DataType = D;

	void filter() {}
	
	@property ContextType context() { return _context; }
	@property DataType data() { return _data; }
	@property void data(DataType value) { 
		_data = value; 
		resetFilters;
	}
	@property void context(ContextType value) { 
		_context = value; 
		resetFilters;
	}

	this() {
	}
	
	this(ContextType context, DataType data) {
		this();
		this.context = context;
		this.data = data;
	}
	
	@property AttributeTree updateFilter() { return _updateAttributes; }
	@property AttributeTree accessFilter() { return _accessAttributes; }
	
	void process() {
	}

	/// Returns a copy of the given json with the access filters applied
	Json jsonFilterAccess(Json json) {
		if (_accessWhiteList) 
			return json.filterIn(_accessAttributes);
		else 
			return json.filterOut(_accessAttributes);
		
	}
	
	/// Returns a copy of the given json with the update filters applied, ie: only fields updatable by the context should be included
	Json jsonFilterUpdate(Json json) {
		if (_updateWhiteList)
			return json.filterIn(_updateAttributes);
		else			
			return json.filterOut(_updateAttributes);
	}

	/// Returns a copy of the given json with both the update and the access filters applied, ie: only fields updatable and accessible by the context should be included
	Json jsonFilter(Json json) {
        return jsonFilterUpdate(jsonFilterAccess(json));
	}

	/// Returns the raw Json that the filters work with. This should be overridden if custom fields are to be added
	Json rawJson() {
		if (!data) return Json(null);
		return data.serializeToJson;
	}
	
	Json toJson() {
		auto json = rawJson;

		json = jsonFilterAccess(json);

		if(_updateAttributes.hasChildren) {
			if (_updateWhiteList)
				json["_updateable"] = _updateAttributes.leafPaths.serializeToJson;
			else			
				 json["_readOnly"] = _updateAttributes.leafPaths.serializeToJson;
		}

		return json;
	}

private: 
	void resetFilters() {
		if (!_context || !_data) return;

		_accessAttributes = new AttributeTree;
		_updateAttributes = new AttributeTree;

		filter();
	}

	bool _accessWhiteList;
	bool _updateWhiteList;

	ContextType _context;
	DataType _data;
	
	AttributeTree _updateAttributes;
	AttributeTree _accessAttributes;
}

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
	
	class TestUserSerializer : ContextSerializer!(TestUser, TestUser) {
		override void filter() {
			accessFilter.add("salary", "job.title");
			updateFilter.add("firstName", "surname", "job.level");
		}
	}

	unittest {
		import aura.data.json.convenience;
		
		auto user = new TestUser;
		user.firstName = "John";
		user.surname = "Smith";
		user.job.title = "Timelord";
		user.salary = 100000;

		auto s = new TestUserSerializer;
		s.data = user;
		s.context = user;

		auto serialized = s.toJson;

		assert(isObject(serialized));
		auto readOnly = serialized["_readOnly"];
		assert(isArray(readOnly));
	}
}

