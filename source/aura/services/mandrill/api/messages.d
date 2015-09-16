module aura.services.mandrill.api.messages;

import aura.data.json;

import aura.services.mandrill.structs;
import aura.services.mandrill.client;

SendResult[] send(Client client, Message m) {
	SendResult[] results;

	client.request("messages/send", m.serializeToJson.wrap("message"), (scope result) {
			results.deserializeJson(result);
	});
	return results;
}

SendResult[] sendTemplate(Client client, string templateName, Message m, TemplateContent[] content = []) {
	SendResult[] results;

	auto requestJson = Json.emptyObject;
	requestJson["template_name"] = templateName;
	requestJson["template_content"] = content.serializeToJson;
	requestJson["message"] = m.serializeToJson;

	client.request("messages/send-template", requestJson, (scope result) {
			results.deserializeJson(result);
		});
	return results;
}
