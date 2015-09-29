module aura.graph.value.serializer;

import aura.graph.value.value;
import aura.graph.value.conv;
import aura.graph.core.exception;

import std.typetuple;
import std.conv;

/**
	Serializer for a plain GraphValue representation.

	See_Also: vibe.data.serialization.serialize, vibe.data.serialization.deserialize, serializeToGraphValue, deserializeGraphValue
*/
struct GraphValueSerializer {
	template isSupportedValueType(T) { enum isSupportedValueType = GraphValue.holdsType!T || is(T == GraphValue); }

	private {
		GraphValue m_current;
		GraphValue[] m_compositeStack;
	}

	this(GraphValue data) { m_current = data; }

	@disable this(this);

	//
	// serialization
	//
	GraphValue getSerializedResult() { return m_current; }
	void beginWriteDictionary(T)() { m_compositeStack ~= GraphValue.emptyObject; }
	void endWriteDictionary(T)() { m_current = m_compositeStack[$-1]; m_compositeStack.length--; }
	void beginWriteDictionaryEntry(T)(string name) {}
	void endWriteDictionaryEntry(T)(string name) { m_compositeStack[$-1][name] = m_current;	}

	void beginWriteArray(T)(size_t) { m_compositeStack ~= GraphValue(GraphValue[].init); }
	void endWriteArray(T)() { m_current = m_compositeStack[$-1]; m_compositeStack.length--; }
	void beginWriteArrayEntry(T)(size_t) {}
	void endWriteArrayEntry(T)(size_t) { m_compositeStack[$-1].append(m_current); }

	void writeValue(T)(in T value)
		if (!is(T == GraphValue))
	{
		static if (isGraphValueSerializable!T) m_current = value.toGraphValue!T;
		else m_current = value;
	}

	void writeValue(T)(GraphValue value) if (is(T == GraphValue)) { m_current = value; }
	void writeValue(T)(in GraphValue value) if (is(T == GraphValue)) { m_current = value.dup; }
	
	//
	// deserialization
	//
	void readDictionary(T)(scope void delegate(string) field_handler)
	{
		enforceGraphValue(m_current.isObject, "Expected GraphValue object, got " ~ m_current.type.to!string);
		auto old = m_current;
		foreach (string key, value; m_current.get!(GraphValue.Object)) {
			m_current = value;
			field_handler(key);
		}
		m_current = old;
	}
	
	void readArray(T)(scope void delegate(size_t) size_callback, scope void delegate() entry_callback)
	{
		enforceGraphValue(m_current.isArray, "Expected GraphValue array, got " ~ m_current.type.to!string);
		auto old = m_current;
		size_callback(m_current.length);
		foreach (ent; old.get!(GraphValue.Array)) {
			m_current = ent;
			entry_callback();
		}
		m_current = old;
	}
	
	T readValue(T)()
	{
		static if (is(T == GraphValue)) return m_current;
		else static if (isGraphValueSerializable!T) return fromGraphValue!T(m_current);
		else return m_current.get!T();
	}
	
	bool tryReadNull() { return m_current.isNull; }
}

/// private
package template isGraphValueSerializable(T) { enum isGraphValueSerializable = is(typeof(T.init.toGraphValue()) == GraphValue) && is(typeof((fromGraphValue!T(GraphValue()))) == T); }

private void enforceGraphValue(string file = __FILE__, typeof(__LINE__) line = __LINE__)(bool cond, lazy string message = "GraphValue exception")
{
	static if (__VERSION__ >= 2065) enforce!GraphException(cond, message, file, line);
	else if (!cond) throw new GraphException(message);
}

private void enforceGraphValue(string file = __FILE__, typeof(__LINE__) line = __LINE__)(bool cond, lazy string message, string err_file, int err_line)
{
	enforce!GraphException(cond, format("%s(%s): Error: %s", err_file, err_line+1, message), file, line);
}

private void enforceGraphValue(string file = __FILE__, typeof(__LINE__) line = __LINE__)(bool cond, lazy string message, string err_file, int* err_line)
{
	enforceGraphValue!(file, line)(cond, message, err_file, err_line ? *err_line : -1);
}

unittest {
	import std.stdio;
	assert(isGraphValueSerializable!double);
	import vibe.data.serialization;

	struct Embedded {
		double score;
		string subject;
	}
	struct Test {
		int number;
		string text;
		@optional Embedded[] grades;
	}

	Test test;
	test.number = 5;
	test.text = "Hello";
	test.grades ~= Embedded(9, "IT");
	test.grades ~= Embedded(8, "Maths");
	GraphValue result = serialize!GraphValueSerializer(test);

	assert(result.isObject);
	assert(result["number"] == 5);
	assert(result["text"] == "Hello");

	GraphValue data = GraphValue.emptyObject;
	data["number"] = 17;
	data["text"] = "DM";
	data["grades"] = GraphValue.emptyArray;
	data["grades"].append(["score": GraphValue("24.0"), "subject": GraphValue("Physics")]);
	auto dTest = deserialize!(GraphValueSerializer, Test)(data);
	assert(dTest.number == 17);
	assert(dTest.text == "DM");
}

import aura.graph.core.model;

GraphValue serializeToGraphValue(M : GraphModelInterface)(M model) {
	return serialize!GraphValueSerializer(model);
}

M deserializeGraphValue(M : GraphModelInterface)(GraphValue value) {
	return deserialize!(GraphValueSerializer, M)(value);
}
