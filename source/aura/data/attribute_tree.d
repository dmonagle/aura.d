module aura.data.attribute_tree;

import std.string;

class AttributeTree {
	enum Separator = ".";

	this() {
	}

	this(string name) {
		_name = name;
	}

	AttributeTree parent;

	@property string[] path() {
		string[] returnPath = parent ? parent.path : [];
		if (_name.length) returnPath ~= _name;
		return returnPath;
	}

	@property AttributeTree[] children() {
		return _children.values;
	}
	
	@property string[] childNames() {
		return _children.keys;
	}

	@property string[] leafPaths(string separator = ".") {
		if (!hasChildren) return [path.join(separator)];

		string[] paths;

		foreach(child; children) {
			paths ~= child.leafPaths;
		}

		return paths;
	}

	@property bool hasChildren() {
		return _children.length ? true : false;
	}

	AttributeTree add(string name) {
		auto names = name.split(Separator);

		if (names.length > 1) {
			auto current = this;
			foreach(n; names)
				current = current.addSingle(n);
			return current;
		}
		else {
			return addSingle(name);
		}
	}

	AttributeTree add(string[] names ...) {
		foreach(name; names) add(name);
		return this;
	}

	/// Returns the AttributeTree at the specified path, if it does not exist, it returns null
	AttributeTree get(string[] path ...) {
		if (!path.length) return this;
		auto nextPath = path[0];
		if (nextPath !in _children) return null;
		auto child = _children[nextPath];
		return child.get(path[1..$]);
	}

	/// Returns true if the given path exists and it has no children
	bool isLeaf(string[] path ...) {
		auto ePath = get(path);
		if (!ePath) return false;
		return ePath.hasChildren ? false : true;
	}
	
	/// Returns true if the given path exists
	bool exists(string[] path ...) {
		return get(path) ? true : false;
	}
	
	void printPretty() {
		import std.stdio;
		import colorize;
		
		string output;
		auto p = path;
		if (p.length) p[$ - 1] = p[$-1].color(fg.light_yellow);
		writeln(p.join(Separator));
		foreach(child; _children) child.printPretty();
	}

private:
	string _name;
	AttributeTree[string] _children;

	AttributeTree addSingle(string name) {
		if (name in _children) return _children[name];
		
		auto child = new AttributeTree(name);
		_children[name] = child;
		child.parent = this;
		return child;
	}
}

AttributeTree serializeToAttributeTree(string[] keys ...) {
	return new AttributeTree().add(keys);
}
