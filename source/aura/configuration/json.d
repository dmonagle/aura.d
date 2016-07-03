module aura.configuration.json;

import aura.data.json;
import std.file;
import std.path;
import std.stdio;
import std.format;

void writeJsonConfig(Json config, string configFileName, bool force = false) {
	if (!exists(configFileName) || force) {
		mkdirRecurse(dirName(configFileName));
	
		auto configFile = File(configFileName, "w");
		configFile.write(config.toPrettyString);
		configFile.close; 
	}
}

/**
	Writes the given config to config files. This will write one master config files as
	well as creating a directory for each top level key. Files will only be overwritten
	if the force paraemeter is set to true.
*/
void saveJsonConfig(T : Json)(T config, string path, string configName, bool force = false)
in {
	assert(config.type == Json.Type.object);
}
body {
	// Create the path if necessary
	auto configFileName = buildPath(path, format("%s.json", configName));
	
	// Create the main config file if it doesn't exist or it's forced
	writeJsonConfig(config, configFileName, force);
	
	// Create the supplemental config files
	auto configPath = buildPath(path, configName);
	foreach(string key, Json value; config) {
		if (value.type == Json.Type.object) {
			auto configFileName =  buildPath(configPath, format("%s.json", key));
			value.writeJsonConfig(configFileName, force);
		}
	}
}	


void saveJsonConfig(T)(T config, string path, string configName, bool force = false) {
	saveJsonConfig(config.serializeToJson, path, configName, force);
}

Json loadJsonConfig(string path, string configName) {
	auto config = Json.emptyObject;
	auto configFileName = buildPath(path, format("%s.json", configName));
	
	// Load the json file that should contain a complete configuration
	if (configFileName.exists) {
		auto jsonString = readText(configFileName);
		config = parseJsonString(jsonString);
	}

	// Load the directory named after the environment that should contain individual json configuration files
	auto configPath = buildPath(path, configName);
	if (configPath.exists && configPath.isDir) {
		foreach(supplementalConfigFileName; dirEntries(configPath, SpanMode.shallow, true)) {
			if (supplementalConfigFileName.extension == ".json") {
				auto jsonString = readText(supplementalConfigFileName);
				auto key = supplementalConfigFileName.baseName.stripExtension;
				auto supplementalConfig = parseJsonString(jsonString);

				if (config[key].type == Json.Type.object) {
					writefln("Merging %s", key);
					config[key] = config[key].jsonMerge(supplementalConfig);
				}
				else {
					writefln("Overwriting %s", key);
					config[key] = supplementalConfig;
				}				
				writefln("%s: %s", key, config);
			}
		}
	}

	return config;
}