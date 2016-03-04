module aura.data.bson.merge;

public import vibe.data.bson;

/**
 * 
 * 
 */
Bson bsonMerge(Bson original, Bson changed) {
	if (original.type != changed.type) {
		return changed;
	}
	
	switch(original.type) {
		case Bson.Type.object: {
			Bson _merged = original;
			
			foreach(string key, value; changed) {
				// set the value if value doesn't exist in the original
				if (original[key].isNull) _merged[key] = changed[key];
				else {
					_merged[key] = bsonMerge(original[key], value);
				}
			}
			
			return _merged;
		} 
		default: {
			return changed;
		}
	}
}

unittest {
	auto j1 = Json.emptyObject;
	
	j1.name = "John";
	j1.surname = "Smith";
	j1.title = "Manager";
	j1.car = Json.emptyObject;
	j1.car.make = "Ford";
	j1.car.model = "Escort";
	j1.scores = Json.emptyArray;
	j1.scores ~= 8;
	j1.scores ~= 8;
	j1.scores ~= 10;
	j1.scores ~= 6;
	j1.scores ~= 6;
	
	
	auto j2 = Json.emptyObject;
	j2.name = "Sarah";
	j2.surname = "Smith";
	j2.age = 65;
	j2.car = Json.emptyObject;
	j2.car.make = "Ford";
	j2.car.model = "Falcon";
	j2.scores = Json.emptyArray;
	j2.scores ~= 7;
	j2.scores ~= 10;
	j2.scores ~= 9;
	j2.scores ~= 6;
	j2.scores ~= 6;
	
	auto b1 = Bson.fromJson(j1);
	auto b2 = Bson.fromJson(j2);
	
	auto merged = bsonMerge(b1, b2).toJson;
	assert(merged.name == "Sarah");
	assert(merged.surname == "Smith");
	assert(merged.title == "Manager");
	assert(merged.age == 65);
	assert(merged.car.model == "Falcon");
}

