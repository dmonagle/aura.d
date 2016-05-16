/**
    An attempt at making an attribute tree as as struct. Not in use at the moment
*/
module aura.graph.value.attribute_tree;

import std.string;
import std.exception : enforce;
import std.typecons : Nullable;

struct AttributeTree {
	static enum Separator = ".";

	string name;

	this(string name) {
		this.name = name;
	}

	this(string name, ref AttributeTree parent) {
		this(name);
		_parent = &parent;
	}


	@property string[] path() {
		string[] returnPath = _parent ? (*_parent).path : [];
		if (name.length) returnPath ~= name;
		return returnPath;
	}

	@property AttributeTree[] children() {
		return _children;
	}

//	@property string[] leafPaths(string separator = ".") {
//		if (!hasChildren) return [path.join(separator)];
//		
//		string[] paths;
//		
//		foreach(child; children) {
//			paths ~= child.leafPaths;
//		}
//		
//		return paths;
//	}
//	
	@property bool hasChildren() {
		return _children.length ? true : false;
	}

	ref AttributeTree add(string name) {
		auto names = name.split(Separator);

		if (names.length > 1) {
			AttributeTree *current = &this;
			foreach(n; names)
				current = &current.addChild(n);
			return *current;
		}
		else {
			return addChild(name);
		}
	}
//	
//	AttributeTree add(string[] names ...) {
//		foreach(name; names) add(name);
//		return this;
//	}
//	
//	/// Returns the AttributeTree at the specified path, if it does not exist, it returns null
//	AttributeTree get(string[] path ...) {
//		if (!path.length) return this;
//		auto nextPath = path[0];
//		if (nextPath !in _children) return null;
//		auto child = _children[nextPath];
//		return child.get(path[1..$]);
//	}
//	
//	/// Returns true if the given path exists and it has no children
//	bool isLeaf(string[] path ...) {
//		auto ePath = get(path);
//		if (!ePath) return false;
//		return ePath.hasChildren ? false : true;
//	}
//	
//	/// Returns true if the given path exists
//	bool exists(string[] path ...) {
//		return get(path) ? true : false;
//	}
//	
	void prettyPrint() {
		import std.stdio;
		//import colorize;

		string output;
		auto p = path;
		if (p.length) p[$ - 1] = p[$-1];
		writeln(p.join(Separator));
		foreach(child; _children) child.prettyPrint();
	}
//	


private:
	AttributeTree[] _children;
	AttributeTree *_parent;

	ref AttributeTree addChild(string name) {
		import std.algorithm;
		auto child = _children.find!"a.name == b"(name);
		if (child.length) return child[0];
		_children ~= AttributeTree(name, this);
		return (_children[$ - 1]);
	}
}

/*
AttributeTree serializeToAttributeTree(string[] keys ...) {
	return new AttributeTree().add(keys);
}
*/

unittest {
	AttributeTree at;

	at.name = "Test";

	assert(!at.hasChildren);
	auto child1 = at.add("Child1");
	assert(at.hasChildren);
	assert(at.children.length == 1);
	at.add("Child1");
	assert(at.children.length == 1);
	at.add("Child2");
	assert(at.children.length == 2);

	child1.name = "RenamedChild1";

	at.prettyPrint;
}