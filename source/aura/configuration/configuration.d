module aura.configuration.configuration;

import aura.configuration;
import aura.data.json;

class Configuration(S) {
    alias data this;
    
    @property string environmentName() { return _environmentName; }
    @property void environmentName(string value) { _environmentName = value; }

    void load() {
		auto newConfig = loadJsonConfig(configPath, environmentName);
        auto currentConfig = _configData.serializeToJson;
        _configData.deserializeJson(currentConfig.jsonMerge(newConfig));
    }
    
   	void load(string path, string environment) {
        configPath = path;
        environmentName = environment;
		load;
	}
	
	void save(bool force = false) {
		saveJsonConfig(_configData, configPath, environmentName, force);
	}

	void save(string path, string environment, bool force = false) {
        configPath = path;
        environmentName = environment;
        save(force);
    }
    
    @property ref S data() { return _configData; }

private:
    S _configData;
    
    string configPath = "config";
    string _environmentName = "development";
}

unittest {
    struct Server {
        string host;
    }
    
    auto config = new Configuration!Server;
    
    config.host = "test";
    assert(config.host == "test");
}

