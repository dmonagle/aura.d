module aura.graph.core.query;

import std.conv;

interface GraphQueryElement {
	string explain() const;
}

class GraphQueryAttribute {
	string name;
	GraphQuery query;
}

class GraphQuery : GraphQueryElement {
	static GraphQuery opCall(string model) {
		auto q = new GraphQuery;
		q.model = model;
		return q;
	}

	static GraphQuery opCall(Q)(string model, Q query) {
		auto q = GraphQuery(model);
		// Do something with the query here
		q.modelQuery = GraphModelQuery(q);
		return q;
	}

	static GraphQuery opCall(Q, A)(string model, Q query, A attributes) {
		auto q = GraphQuery(model, query);
		// Do something with the attributes here
		return q;
	}

	override string explain() const {
		auto returnString = "Querying model: " ~ model;
		if (modelQuery) returnString ~= "\n\t" ~ modelQuery.explain();
		return returnString;
	}

	GraphQuery limit(int limit) {
		modelQuery.options.limit = limit;
		return this;
	}
	
	GraphQuery offset(int offset) {
		modelQuery.options.offset = offset;
		return this;
	}
	
	GraphQuery sort(string attribute, GraphSortDirection direction = GraphSortDirection.ascending) {
		modelQuery.options.sort ~= GraphSort(attribute, direction);
		return this;
	}
	
private:
	string model;
	GraphModelQuery modelQuery;
	GraphQueryAttribute[] attributes;
}


enum GraphSortDirection {
	ascending = 1,
	descending = -1
}

struct GraphSort {
	string attribute;
	GraphSortDirection direction = GraphSortDirection.ascending;
}

struct GraphQueryOptions {
	int limit;
	int offset;
	GraphSort[] sort;
}

class GraphModelQuery : GraphQueryElement {
	static GraphModelQuery opCall(Q)(Q query) {
		auto q = new GraphModelQuery;

		return q;
	}

	override string explain() const {
		auto returnString = "Model Query:";
		if (options.limit) returnString ~= " limit(" ~ options.limit.to!string ~ ")";
		if (options.offset) returnString ~= " offset(" ~ options.offset.to!string ~ ")";
		return returnString;
	}

private:
	GraphQueryOptions options;
}

class GraphFilter : GraphQuery {
}

unittest {
	import std.stdio;
	import colorize;
	
	writefln("*** Testing the Graph Query ***".color(fg.light_green));
	auto query1 = GraphQuery("person");
	writeln(query1.explain.color(fg.light_magenta));

	auto query2 = GraphQuery("company", ["query": "sample"]);
	writeln(query2.explain.color(fg.light_blue));

	auto query3 = GraphQuery("employment", ["query": "sample"], ["list", "of", "attributes"]).limit(5).offset(10).sort("startDate");
	writeln(query3.explain.color(fg.light_yellow));
	writefln("*** End Graph Query Testing ***".color(fg.green));
}