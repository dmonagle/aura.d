module aura.controllers.elasticsearch;

import aura.controllers.pagination;
import aura.data.json;

import elasticsearch;

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

ESParams elasticsearchParameters(PaginationMeta pagination) {
	ESParams p;
	
	p["from"] = pagination.offset.to!string;
	p["size"] = pagination.perPage.to!string;
	
	return p;
}