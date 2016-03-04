module aura.data.yaml.json;

import vibe.data.json;
import yaml;

/// Converts a YAML node to Json
Json toJson(ref Node node) {
	Json j = Json(null);
	
	if (node.isScalar) {
		return Json(node.as!string);
	}
	else if (node.isMapping) {
		j = Json.emptyObject;
		foreach(string key, Node childNode; node)
			j[key] = childNode.toJson;
	}
	else if (node.isSequence) {
		j = Json.emptyArray;
		foreach(Node childNode; node)
			j ~= childNode.toJson;
	}
	
	return j;
}

