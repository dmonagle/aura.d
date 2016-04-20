module aura.graph.elasticsearch.adapter;

public import elasticsearch;

import aura.graph;

import vibe.core.log;
import vibe.inet.url;
import std.string;

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

    /// Inserts or updates a model into 
	void index(M : GraphModelInterface)(M model) {
        auto json = toIndexedJson(model);
        ES_FilterReservedFieldNames(json);
		client.index(containerNameFor(model.graphType), model.graphType, model.graphId, json.toString);
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

    /// Deserialize the given data back to a GraphModelInterface object
	GraphModelInterface deserializeHit(string graphType, Json data) {
		import std.format;

        auto source = data["_source"];
        if (source.type != Json.Type.object) return null;
        
		switch (graphType) {
			foreach(ModelType; Models) {
				case ModelType.stringof:
                    ModelType model;
                    model.deserializeJson(source);
                    model.graphId = data["_id"].get!string;
                    return model;
			}
			default: assert(false, format("Type '%s' not supported by adapter", graphType));
		}
	}

    /// Iterates over the hits in the given json response, deserializes the model and calls the callback for each deserialized `M`
    void deserializeHits(string graphType, Json responseJson, void delegate(GraphModelInterface, Json) callback) {
        // The response should contain a hits object
        auto hitsJson = responseJson["hits"]; 
        if (hitsJson.type != Json.Type.object) return;
        
        // The hitsJson should contain a hits array
        auto hits = hitsJson["hits"];
        if (hits.type != Json.Type.array) return;
        
        foreach(hit; hits) {
			auto result = deserializeHit(graphType, hit);
            callback(result, hit);
        }
    }

    /// ditto
    void deserializeHits(M : GraphModelInterface)(Json responseJson, void delegate(M, Json) callback) {
        deserializeHits(M.stringof, responseJson, (model, meta) {
            callback(cast(M)model, meta);
        });
    }
    
    /// ditto
    auto deserializeHits(M : GraphModelInterface)(Json responseJson) {
		M[] _results;

        deserializeHits(M.stringof, responseJson, (model, meta) {
            _results ~= cast(M)model;
        });
        
        return _results;
    }

	void injectHits(M : GraphModelInterface)(Json responseJson, void delegate(M, Json) callback, bool snapshot = true) {
		deserializeHits!M(responseJson, (model, meta){
			graph.inject(model, snapshot);		
			callback(model, meta);
		});
	} 
    
    /// Injects hits into the graph. 
	M[] injectHits(M : GraphModelInterface)(Json responseJson, bool snapshot = true) 
	in {
		assert(graph);
	}
	body {
		M[] _results;

        injectHits!M(responseJson, (model, meta) {
			_results ~= model;
		}, snapshot);

		return _results;
	}

	
	void injectSearch(M : GraphModelInterface)(string searchBody, ESParams params, void delegate(GraphModelInterface, Json) callback, bool snapshot = true) 
	in {
		assert(graph);
	}
	body {
		auto jsonResponse = search!M(searchBody, params);
		
		injectHits!M(jsonResponse, (model, meta) {
			callback(model, meta);
		}, snapshot);
	}

	/// ditto	
	void injectSearch(M : GraphModelInterface)(string searchBody, void delegate(GraphModelInterface, Json) callback, bool snapshot = true) {
		injectSearch!M(searchBody, ESParams(), callback, snapshot);
	}
	
	M[] injectSearch(M : GraphModelInterface)(string searchBody, ESParams params = ESParams()) {
		M[] _results;

        injectSearch!M(searchBody, params, (model, meta) {
            _results ~= cast(M)model;
        });
        
        return _results;
	}
    
    // Calls get directly on elasticsearch and deserializes the model
    M get(M : GraphModelInterface)(string id, bool snapshot = true)
    in {
        assert(graph, "Called get on elasticsearch adapter without a graph set");
    } 
    body {
        import elasticsearch.api.actions.get;
        auto response = client.get(containerNameFor(M.stringof), id);
        
        auto jsonResponse = response.jsonBody;
        // import std.stdio;
        // writefln("%s", jsonResponse.toPrettyString);

        if (jsonResponse["found"].get!bool) {
            return graph.inject(cast(M)deserializeHit(M.stringof, jsonResponse), snapshot);
        }
        
        return null;
    }

	override GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit = 0) {
		GraphModelInterface[] results;

        ESParams params;
		
        auto limitQuery = limit ? format(`,"size":%s`, limit) : "";
        params["body"] = format(`{"query":{"term":{"%s": "%s"}}%s}`, key, value, limitQuery);
        //params["body"] = `{"query":{"match_all": {}}}`;
		params["index"] = containerNameFor(graphType);
	    params["type"] = graphType;
		
		import std.stdio;
        writefln("Query: %s", params["body"]);
        writefln("Container: %s", params["index"]);
		auto response = client.search(params);
        writefln("%s", response.jsonBody);

        foreach(hit; response.jsonBody["hits"]["hits"]) {
			auto result = deserializeHit(graphType, hit);
			result.graphPersisted = true;
            result.graphUntouch;
			results ~= result;
        }

		return results;
	}


private:
	static {
		Client _client;
		string[] _hosts;
		string _prefix;
	}
}

