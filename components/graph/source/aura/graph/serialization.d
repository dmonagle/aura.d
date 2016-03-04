/// Private methods borrowed from vibe.d 
module aura.graph.serialization;

import std.typetuple;
import vibe.data.serialization;
import vibe.internal.meta.traits;
public import vibe.internal.meta.uda;

package template SerializableFields(COMPOSITE)
{
	alias SerializableFields = FilterSerializableFields!(COMPOSITE, __traits(allMembers, COMPOSITE));
}

package template hasAttribute(T, alias decl) { enum hasAttribute = findFirstUDA!(T, decl).found; }

package template FilterSerializableFields(COMPOSITE, FIELDS...)
{
	static if (FIELDS.length > 1) {
		alias FilterSerializableFields = TypeTuple!(
			FilterSerializableFields!(COMPOSITE, FIELDS[0 .. $/2]),
			FilterSerializableFields!(COMPOSITE, FIELDS[$/2 .. $]));
	} else static if (FIELDS.length == 1) {
		alias T = COMPOSITE;
		enum mname = FIELDS[0];
		static if (isRWPlainField!(T, mname) || isRWField!(T, mname)) {
			alias Tup = TypeTuple!(__traits(getMember, COMPOSITE, FIELDS[0]));
			static if (Tup.length != 1) {
				alias FilterSerializableFields = TypeTuple!(mname);
			} else {
				static if (!hasAttribute!(IgnoreAttribute, __traits(getMember, T, mname)))
					alias FilterSerializableFields = TypeTuple!(mname);
				else alias FilterSerializableFields = TypeTuple!();
			}
		} else alias FilterSerializableFields = TypeTuple!();
	} else alias FilterSerializableFields = TypeTuple!();
}