module aura.util.null_bool;

public import std.typecons;

bool isTrue(Nullable!bool b) {
	if (b.isNull) return false;
	return b.get;
}

bool isFalse(Nullable!bool b) {
	if (b.isNull) return true;
	return !b.get;
}

bool isNotNull(Nullable!bool b) {
	return !b.isNull;
}

unittest {
	Nullable!bool b;
	
	assert(b.isNull);
	assert(b.isFalse);
	assert(!b.isTrue);
	
	b = true;
	assert(!b.isFalse);
	assert(b.isTrue);
	
	b = false;
	assert(b.isFalse);
	assert(!b.isTrue);
}