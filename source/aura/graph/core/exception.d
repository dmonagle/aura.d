module aura.graph.core.exception;

class GraphException : Exception {
	this(string s, string file = __FILE__, ulong line = __LINE__) { super(s, file, line); }
}

