module aura.graph.elasticsearch.proxy;

import aura.graph.core;
import elasticsearch;

import aura.data.json;
import vibe.inet.url;

class ElasticsearchIndexProxy(Models ...) : GraphEventListener {
	mixin GraphEventListenerImplementation;
	mixin GraphModelStoreImplementation;

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

	void index(M : GraphModelInterface)(M model) {
		static if (__traits(compiles, model.toIndexedJson)) {
			auto json = model.toIndexedJson;
		}
		else {
			auto json = model.serializeToJson;
		}

		client.index(containerNameFor(model.graphType), model.graphType, model._id.toString, json.toString);
	}

	/// Return the name of the container to be used for the given modelName
	/// by default this returns the typename verbatim. This method can be overridden to return custom containerNames
	string containerNameFor(string typeName) {
		import aura.util.inflections.en;
		import aura.util.string_transforms;

		return prefix ~ typeName.snakeCase.pluralize;
	}

	void graphDidSync() {
		foreach(M; Models) {
			foreach(m; modelStore!M) {
				index(cast(M)m);
			}
		}
	}

	void modelDidSave(GraphModelInterface model) {
		modelStore(model.graphType).addModel(model);
	}

	void modelDidDelete(GraphModelInterface model) {
	// TODO: Remove it from elasticsearch here too
		modelStore(model.graphType).removeModel(model);
	}

private:
	static {
		Client _client;
		string[] _hosts;
		string _prefix;
	}
}

