module aura.graph.elasticsearch.proxy;

import aura.graph;
import elasticsearch;

import aura.data.json;
import vibe.inet.url;
import vibe.core.log;

class ElasticsearchIndexProxy(Adapter : GraphAdapterInterface) : GraphEventListener {
	mixin GraphEventListenerImplementation;
	mixin GraphModelStoreImplementation;
	mixin GraphInstanceImplementation;

	Adapter esAdapter;

	this() {
		esAdapter = new Adapter;
	}

	void graphDidSync() {
		foreach(M; Adapter.Models) {
			auto modelLength = modelStore!M.length;
			if (modelLength) {
				if (modelLength == 1) {
					logDebug("ElasticsearchIndexProxy: Syncing %s %s models with elasticsearch", modelLength, M.stringof);
					foreach(m; modelStore!M) {
						esAdapter.index(cast(M)m);
					}
				}
				else {
					auto bulk = EsBulkProxy(esAdapter.client);
					logDebug("ElasticsearchIndexProxy: Bulk syncing %s %s models with elasticsearch", modelLength, M.stringof);
					foreach(m; modelStore!M) {
                        auto json = esAdapter.toIndexedJson(cast(M)m);
                        ES_FilterReservedFieldNames(json);
						bulk.appendIndex(esAdapter.containerNameFor(M.stringof), m.graphType, m.graphId, json);
					}
					bulk.flush();
				}
			}
		}
	}

	void modelDidSave(GraphModelInterface model) {
		modelStore(model.graphType).addModel(model);
	}

	void modelDidDelete(GraphModelInterface model) {
	// TODO: Remove it from elasticsearch here too
		modelStore(model.graphType).removeModel(model);
		esAdapter._delete(model);
	}
}

