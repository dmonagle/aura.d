module aura.data.json.context_serializer;

import aura.data.json;

interface ContextSerializerInterface {
	alias FieldList = string[];
	Json toJson();
	@property FieldList readOnlyFields();
	@property FieldList redactedFields();
}

class ContextSerializer(ContextType, DataType) : ContextSerializerInterface{
	void filter() {}
	
	@property ContextType context() { return _context; }
	@property void context(ContextType value) { 
		_context = value; 
		reset(true);
	}
	@property DataType data() { return _data; }
	@property void data(DataType value) { 
		_data = value; 
		reset(true);
	}
	@property Json json() { return _json; }
	
	this() {}
	
	this(ContextType context, DataType data) {
		this.context = context;
		this.data = data;
	}
	
	@property ContextSerializerInterface.FieldList readOnlyFields() { return _readOnlyFields; }
	@property ContextSerializerInterface.FieldList redactedFields() { return _redactedFields; }
	
	void process() {
		filter();
		
		_json = data.serializeToJson;
		
		_json.jsonFilterOutInPlace(redactedFields);
		auto roF = readOnlyFields;
		if (roF.length) {
			_json["_readOnly"] = roF.serializeToJson;
		}
	}
	
	Json toJson() {
		return _json;
	}
	
protected:
	void reset(bool andProcess = false) {
		_json = Json(null);
		_redactedFields = [];
		_readOnlyFields = [];
		if (andProcess && _data && _context) process;
	}
	
	void addRedacted(ContextSerializerInterface.FieldList fields ...) {
		_redactedFields ~= fields;
	}
	
	void addReadOnly(ContextSerializerInterface.FieldList fields ...) {
		_readOnlyFields ~= fields;
	}
	
private: 
	ContextType _context;
	DataType _data;
	
	Json _json; // Holds the json being serialized
	ContextSerializerInterface.FieldList _readOnlyFields;
	ContextSerializerInterface.FieldList _redactedFields;
}