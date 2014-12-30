module aura.data.bson.util;

public import vibe.data.bson;

/// Deserializes a list of attributes into a model when the model attribute names are not identical to the source
/// The mapping parameter must have an even number of strings in (destAttribute, sourceAttribute) configuration.
void deserializeManyBson(T, mappings ...)(ref T dest, Bson source) {
	import std.traits;
	import vibe.core.log;
	
	static assert(!(mappings.length % 2), "You must provide an even number of parameters for conversion (dest, source)");
	foreach (index, destAttr; mappings) {
		static if (!(index % 2)) {
			static if (mappings[index + 1].length)
				immutable string sourceAttr = mappings[index + 1];
			else
				immutable string sourceAttr = destAttr;
			auto sourceField = source[sourceAttr];
			logDebugV("Deserializing %s(%s) from BSON(%s)", destAttr, typeof(dest).stringof, sourceField.type);
			if (!sourceField.isNull) {
				deserializeBson(__traits(getMember, dest, destAttr), sourceField);
			}
			else {
				static if (__traits(compiles, __traits(getMember, dest, destAttr).isNull)) 
					__traits(getMember, dest, destAttr).nullify;
			}
		}
	}
}

void deserializeBsonWithNullValue(T)(ref T dest, Bson bson, T defaultValue) {
	if (bson.type == Bson.Type.null_) 
		dest = defaultValue;
	else
		dest.deserializeBson(bson);
}