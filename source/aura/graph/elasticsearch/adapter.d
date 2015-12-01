module aura.graph.elasticsearch.adapter;

import aura.graph.core.model;
import aura.graph.core.adapter;

import elasticsearch;

import vibe.core.log;
import vibe.inet.url;

class GraphEsAdapter(M ...) : GraphAdapter!(M) {
	@property ref string[] hosts() { return _hosts; }
	
	@property Client client() {
		import vibe.core.log;
		
		if (!_client) {
			_client = new Client();
			foreach(host; _hosts) {
				auto url = URL.parse(host);
				_client.addHost(Host(
						url.host,
						url.port,
						url.schema,
						url.pathString,
						url.username,
						url.password
						)
					);
			}
		}
		return _client;
	}
	
	/// Returns an index name for the specified container name by prepending the database name
	string indexName(const string cName) {
		return databaseName ~ "_" ~ cName;
	}
	
	void ensureIndex(M)(string content) {
		auto name = indexName(containerName!M);
		if (!client.indexExists(name)) {
			logInfo("Creating Elasticsearch Index: '%s'", name);
			client.createIndex(name, content);
		}
	}
	
	void deleteIndex(M)() {
		auto name = indexName(containerName!M);
		if (client.indexExists(name)) {
			logInfo("Deleting Elasticsearch Index: '%s'", name);
			client.deleteIndex(name);
		}
	}

	void refreshIndex(M)() {
		auto name = indexName(containerName!M);
		if (client.indexExists(name)) {
			logInfo("Manually refreshing Elasticsearch Index: '%s'", name);
			client.refreshIndex(name);
		}
	}

	Json search(M)(string searchBody, ESParams params = ESParams()) {
		params["body"] = searchBody;
		params["index"] = indexName(containerName!M);
		if ("type" !in params)
			params["type"] = M.stringof;
		else {
			// If the type is specified as blank, remove the type
			if (!params["type"].length) params.remove("type");
		}
		
		auto response = client.search(params);
		
		return response.jsonBody;
	}

	Json scroll(string scroll_id, ESParams params = ESParams()) {
		params["scroll_id"] = scroll_id;
		if ("scroll" !in params) params["scroll"] = "1m";
		if ("size" !in params) params["size"] = "2000";		

		auto response = client.scroll(params);
		return response.jsonBody;
	}

	bool save(M : GraphStateInterface)(M model) {
		static if (__traits(compiles, model.toIndexedJson)) {
			auto json = model.toIndexedJson;
		}
		else {
			auto json = model.serializeToJson;
		}

		json.remove("_type");
		json.remove("_id");
		client.index(indexName(containerName!M), model.graphType, model.graphState.id, json.toString);
		return true;
	}

	/// Removes the model from the database
	bool remove(M : GraphStateInterface)(M model) {
		client.delete_(indexName(containerName!M), model.graphType, model.graphState.id);
		return true;
	}


	M find(M : GraphStateInterface, V)(string key, V value) {
		assert("The EsAdapter does not currently support lookup up models");
	}

	M find(M : GraphStateInterface)(string id) {
		assert("The EsAdapter does not currently support lookup up models");
	}

private:
	Client _client;
	string[] _hosts;
}