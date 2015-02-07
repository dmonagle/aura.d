module aura.configuration.directoryReader;

import aura.data.json;
import aura.data.yaml;

import std.file;
import std.path;
import std.algorithm;

Node processYamlConfigPath(string path, string environment) {
	auto y = processYamlConfigDirectory(path, environment);
	y = y.merge(processYamlConfigDirectory(buildPath(path, environment)));
	
	return y;
}



/// Processes a single directory
Node processYamlConfigDirectory(string directory, string environment = "") {
	auto n = Node(cast(string[string])null);
	
	if (!directory.exists || !directory.isDir) return n;
	// Iterate a directory in breadth
	foreach (string path; dirEntries(directory, SpanMode.shallow))
	{
		if ([".yml", ".yaml", "conf", "config"].canFind(path.extension)) {
			auto node = processYamlConfigFile(path, environment);
			if (node.isValid) n[path.baseName(path.extension)] = node;
		}
	}
	
	return n;
}


Node processYamlConfigFile(string fileName, string environment = "") {
	Node returnNode;
	
	auto yamlConfig = Loader(fileName).load();
	if (environment.length) {
		if (yamlConfig.containsKey(environment)) 
			returnNode = yamlConfig[environment];
	}
	else {
		returnNode = yamlConfig;
	}
	
	return returnNode;
}

unittest {
	import std.stdio;
	import colorize;

	auto yaml = processYamlConfigPath("test/configuration", "development");
	writeln(yaml.toJson.toPrettyString.color(fg.light_yellow));

	yaml = processYamlConfigPath("test/configuration", "production");
	writeln(yaml.toJson.toPrettyString.color(fg.light_blue));

}

