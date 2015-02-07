module aura.data.yaml.merge;

import yaml;

/**
 * 
 * 
 */
Node merge(Node original, Node changed) {
	if (original.isMapping && changed.isMapping) {
		return changed;
	}

	if (changed.isMapping) {
		Node _merged = original;
		
		foreach(string key, Node value; changed) {
			// set the value if value doesn't exist in the original
			if (!(key in original)) _merged[key] = changed[key];
			else {
				_merged[key] = merge(original[key], value);
			}
		}
		
		return _merged;
	}
	else {
		return changed;
	}
}