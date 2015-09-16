module aura.configuration.yaml;

import aura.data.json;
import aura.data.yaml;

import std.file;
import std.path;
import std.algorithm;

debug {
	import std.stdio;
}

alias YamlConfig = Node;

/// Sets the passed in value to the index specified by key
void set(T)(Node n, string key, ref T value) {
	if (n.containsKey(key))	value = n[key].as!T;
}

/// Sets the passed in array to the array at the index specified by key
void setArray(T)(Node n, string key, ref T[] value) {
	if (n.containsKey(key)) {
		value = [];
		foreach(Node node; n[key]) {
			value ~= node.as!T;
		}
	}
}

Node processYamlConfigPath(string path, string environment) {
	auto y = processYamlConfigDirectory(path, environment);
	y = y.merge(processYamlConfigDirectory(buildPath(path, environment)));
	
	return y;
}

/// Processes a single directory
Node processYamlConfigDirectory(string directory, string environment = "") {
	auto n = Node(cast(string[string])null);
	
	if (!directory.exists || !directory.isDir) return n;
	debug writefln("Processing Config Directory '%s' for environment '%s'", directory, environment);
	// Iterate a directory in breadth
	foreach (string path; dirEntries(directory, SpanMode.shallow))
	{
		if ([".yml", ".yaml", ".conf", ".config"].canFind(path.extension)) {
			auto node = processYamlConfigFile(path, environment);
			if (node.isValid) n[path.baseName(path.extension)] = node;
		}
	}
	
	return n;
}


Node processYamlConfigFile(string fileName, string environment = "") {
	Node returnNode;
	
	debug writefln("Processing Config File '%s' for environment '%s'", fileName, environment);
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

/*
unittest {
	import std.stdio;
	import colorize;
	
	auto yaml = processYamlConfigPath("test/configuration", "development");
	writeln(yaml.toJson.toPrettyString.color(fg.light_yellow));
	
	yaml = processYamlConfigPath("test/configuration", "production");
	writeln(yaml.toJson.toPrettyString.color(fg.light_blue));
	
}
*/
