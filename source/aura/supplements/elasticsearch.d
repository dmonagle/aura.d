module aura.supplements.elasticsearch;

import elasticsearch.api.parameters;
import elasticsearch.client;
import elasticsearch.api.actions.scroll;

import vibe.http.common;

Json scroll(Client client, string scroll_id, string scroll = "1m") {
        ESParams params;
        params["scroll_id"] = scroll_id;
        params["scroll"] = scroll;

		auto response = elasticsearch.api.actions.scroll.scroll(client, params);
		return response.jsonBody;
}

