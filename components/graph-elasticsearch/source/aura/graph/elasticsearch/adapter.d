module aura.graph.elasticsearch.adapter;

public import elasticsearch;

import aura.graph;

import vibe.core.log;
import vibe.inet.url;

/// Elasticsearch adapter for Graph
class GraphElasticsearchAdapter(M ...) : GraphAdapter!M {
	alias Models = M;
	static @property ref string[] hosts() { return _hosts; }
	static @property ref string prefix() { return _prefix; }
	
	static @property Client client() {
		if (!_client) {
			Host[] esHosts;
			
			foreach(host; _hosts) {
				auto url = URL.parse(host);
				esHosts ~= Host(
					url.host,
					url.port,
					url.schema,
					url.pathString,
					url.username,
					url.password
					);
			}
			_client = new Client(esHosts);
		}
		return _client;
	}

	/// Returns the indexed Json representation of the given model
	static Json toIndexedJson(M : GraphModelInterface)(M model) {
		static if (__traits(compiles, model.toIndexedJson)) {
			return model.toIndexedJson;
		}
		else {
			return model.serializeToJson;
		}
	}

	/// Return the name of the container to be used for the given modelName
	/// by default this returns the typename verbatim. This method can be overridden to return custom containerNames
	override string containerNameFor(string typeName) {
		import inflections.en;
		import transforms.snake;
		
		return prefix ~ typeName.snakeCase.pluralize;
	}

	void index(M : GraphModelInterface)(M model) {
		client.index(containerNameFor(model.graphType), model.graphType, model.graphId, toIndexedJson(model).toString);
	}

	/// Deletes the index associated with the given model
	void deleteIndex(M : GraphModelInterface)() {
		auto indexName = containerNameFor(M.stringof);
		client.deleteIndex(indexName);
	}

	/// Ensures the index associated with the given model
	void ensureIndex(M)(string content) {
		auto name = containerNameFor(M.stringof);
		if (!client.indexExists(name)) {
			logInfo("Creating Elasticsearch Index: '%s'", name);
			client.createIndex(name, content);
		}
	}

	/// Calls search on the elasticsearch client
	Json search(M : GraphModelInterface)(string searchBody, ESParams params = ESParams()) {
		params["body"] = searchBody;
		params["index"] = containerNameFor(M.stringof);
		if ("type" !in params)
			params["type"] = M.stringof;
		else {
			// If the type is specified as blank, remove the type
			if (!params["type"].length) params.remove("type");
		}
		
		auto response = client.search(params);
		
		return response.jsonBody;
	}

	/// Deletes the model from elasticsearch
	bool _delete(GraphModelInterface model) {
		auto index = containerNameFor(model.graphType);
		logDebugV("GraphEsAdapter: Removing from index %s: %s", index, model.graphId);
		client.delete_(index, model.graphType, model.graphId);
		return true;
	}

    /// Makes sure the index for the `M` model is synced
	void refreshIndex(M)() {
		auto name = containerNameFor(M.stringof);
		if (client.indexExists(name)) {
			logDebug("Manually refreshing Elasticsearch Index: '%s'", name);
			client.refreshIndex(name);
		}
	}


	override GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit = 0) {
		GraphModelInterface[] results;

		/*
		auto cursor = getCollection(graphType).find([key: value.toBson]);
		if (limit) cursor.limit(limit);
		
		while (!cursor.empty) {
			auto bson = cursor.front;
			auto result = deserialize(graphType, bson);
			result.graphPersisted = true;
			results ~= result;
			cursor.popFront;
		}
		*/

		return results;
	}


private:
	static {
		Client _client;
		string[] _hosts;
		string _prefix;
	}
}

