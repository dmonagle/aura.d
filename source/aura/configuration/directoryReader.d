module aura.configuration.directoryReader;

import aura.data.json;

import std.file;
import std.path;
import yaml;
import std.algorithm;

struct DirectoryReader {
	this(string directory, string environment) {
		_configDirectory = directory;
		_environment = environment;
	}

	@property string environment() {
		return _environment;
	}

	@property void environment(string e) {
		_environment = e;
	}

	Json process() {
		auto j = Json.emptyObject;

		j = j.jsonMerge(processDirectory(_configDirectory));
		j = j.jsonMerge(processDirectory(buildPath(_configDirectory, _environment), false));

		return j;
	}

private:
	Json processDirectory(string directory, bool requireEnvironmentKey = true) {
		Json j = Json.emptyObject;

		if (!directory.exists || !directory.isDir) return j;
		// Iterate a directory in breadth
		foreach (string path; dirEntries(directory, SpanMode.shallow))
		{
			if ([".yml", ".yaml"].canFind(path.extension)) {
				auto node = processYamlFile(path, requireEnvironmentKey);
				if (node.isValid) j[path.baseName(path.extension)] = node.toJson;
			}
		}

		return j;
	}

	Node processYamlFile(string fileName, bool requireEnvironmentKey) {
		Node returnNode;

		auto yamlConfig = Loader(fileName).load();
		if (requireEnvironmentKey) {
			if (yamlConfig.containsKey(_environment)) 
				returnNode = yamlConfig[_environment];
		}
		else {
			returnNode = yamlConfig;
		}

		return returnNode;
	}

	string _configDirectory;
	string _environment;
}

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

unittest {
	import std.stdio;
	import colorize;

	auto config = new DirectoryReader("test/configuration", "development");

	auto json = config.process;
	writeln(json.toPrettyString.color(fg.light_yellow));

	config.environment = "production";
	json = config.process;
	writeln(json.toPrettyString.color(fg.light_blue));

}

