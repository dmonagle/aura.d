module aura.graph.elasticsearch.adapter;

public import elasticsearch;

import aura.graph.core;

import vibe.core.log;
import vibe.inet.url;

/// Elasticsearch adapter for Graph
class GraphElasticsearchAdapter(Models ...) : GraphAdapter!Models {
	/// A string array of elasticsearh hosts to seed the client with
	@property ref string[] hosts() { return _hosts; }

	@property Client client() {
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

private:
	Client _client;
	string[] _hosts;
}

