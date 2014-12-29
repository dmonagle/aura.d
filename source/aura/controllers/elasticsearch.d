module aura.controllers.elasticsearch;

import vibe.http.router;
import vibe.web.web;
import aura.data.json;

import elasticsearch.parameters;

enum pagination = before!paginationPred("_pagination");

struct PaginationMeta {
	import std.math;
	
	int page = 1;
	int perPage = 20;
	int pages;

	// Returns the result offset for the current page
	@property int offset() {
		if (page == 0) return 0;
		return (page - 1) * perPage;
	}

	@property int records() { return _records; }
	
	@property void records(int value) {
		pages = cast(int)((cast(double)value / perPage).ceil);
		adjustForPageOverflow;
		_records = value;
	}
	
	/// Adjusts the current page if the current page is creater than the number of pages
	void adjustForPageOverflow(bool goToMax = true) {
		if (page > pages) 
			page = goToMax ? pages : 1;
	}
	
protected:
	int _records;
}

unittest {
	PaginationMeta p;
	
	p.records = 0;
	assert(p.pages == 0);
	
	p.records = 1;
	assert(p.pages == 1);
	
	p.records = 20;
	assert(p.pages == 1);
	
	p.records = 21;
	assert(p.pages == 2);
	
	assert(p.offset == 0);
	
	p.perPage = 4;
	p.page = 2;
	assert(p.offset == 4);
}

unittest {
	PaginationMeta p;
	
	p.records = 200;
	p.page = 5;
	p.records = 50;
	assert(p.page == 3);
	
}

PaginationMeta paginationPred(HTTPServerRequest req, HTTPServerResponse res) {
	PaginationMeta p;
	
	if ("page" in req.query) 
		try
			p.page = req.query.get("page").to!int;
	catch 
		//enforceHTTP(false, HTTPStatus.unprocessableEntity, "page must be a valid integer");
		p.page = 1;
	
	try
		if ("per_page" in req.query) p.page = req.query.get("per_page").to!int;
	catch
		//enforceHTTP(false, HTTPStatus.unprocessableEntity, "per_page must be a valid integer");
		p.perPage = 20;
	
	return p;
}

Json extractElasticsearchResults(Json searchResults, string key, ref PaginationMeta pagination) {
	auto jsonRecords = Json.emptyArray;
	
	pagination.records = searchResults.hits.total.to!int;
	
	
	foreach(hit; searchResults.hits.hits) {
		auto jsonRecord = hit._source;
		jsonRecord._score = hit._score;
		jsonRecords ~= jsonRecord;
	}
	
	auto json = jsonRecords.wrap(key);
	json.meta = Json.emptyObject;
	json.meta.pagination = pagination.serializeToJson;
	json.meta.aggregations = searchResults.aggregations;
	
	return json;
}

Parameters elasticsearchParameters(PaginationMeta pagination) {
	Parameters p;
	
	p["from"] = pagination.offset.to!string;
	p["size"] = pagination.perPage.to!string;
	
	return p;
}