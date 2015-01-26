module aura.persistence.elasticsearch.adapter;

public import aura.persistence.core;

public import elasticsearch.parameters;
import elasticsearch.client;
import elasticsearch.api.actions.base;
import elasticsearch.api.actions.indices;

import vibe.core.log;
import vibe.inet.url;

class EsAdapter(M ...) : PersistenceAdapter!M {
	private {
		Client _client;
		string[] _hosts;

		CacheContainer!Json _cache;
	}

	this() {
	}

	this(string applicationName, string environment, string[] hosts ...) {
		super(applicationName, environment);
		_hosts = hosts;
	}

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

	void ensureIndex(M)(string content, bool drop = false) {
		auto name = fullName(modelMeta!M.containerName);
		if (drop) {
			deleteIndex!M;
		}
		if (!_client.indexExists(name)) {
			logInfo("Creating Elasticsearch Index: '%s'", name);
			_client.createIndex(name, content);
		}
	}

	void deleteIndex(M)() {
		auto name = fullName(modelMeta!M.containerName);
		if (_client.indexExists(name)) {
			logInfo("Deleting Elasticsearch Index: '%s'", name);
			_client.deleteIndex(name);
		}
	}

	void save(M)(const ref Json model) {
		auto meta = modelMeta!M;
		client.index(fullName(meta.containerName), meta.type, model._id.to!string, model.toString());
	}

	void save(M)(M model) {
		static if (__traits(compiles, model.toIndexedJson)) {
			auto json = model.toIndexedJson;
		}
		else {
			auto json = model.serializeToJson;
		}

		save!M(json);
	}

	Json search(M)(string searchBody, Parameters params = Parameters()) {
		auto meta = modelMeta!M;

		params["body"] = searchBody;
		params["index"] = fullName(meta.containerName);
		if ("type" !in params)
			params["type"] = meta.type;
		else {
			// If the type is specified as blank, remove the type
			if (!params["type"].length) params.remove("type");
		}

		auto response = client.search(params);

		return response.jsonBody;
	}

	/// Returns an array of deserialized models matching the list of ids given
	ModelType[] findModel(ModelType, string key = "id", IdType)(IdType[] ids ...) {
		ModelType[] returnModels;

		return returnModels;
	}
	
	/// Returns a single deserialized model matching the given id
	ModelType findModel(ModelType, string key = "id", IdType)(IdType id) {
		ModelType returnModel;
		
		return returnModel;
	}
	
	bool save(M)(ref M model) {
		return true;
	}
	
	bool remove(M)(ref M model) {
		return true;
	}

}
