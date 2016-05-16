module aura.graph.events;

import aura.graph;

interface GraphEventListener : GraphInstanceInterface {
	void graphWillSync();
	void modelWillSave(GraphModelInterface);
	void modelDidSave(GraphModelInterface);
	void modelWillDelete(GraphModelInterface);
	void modelDidDelete(GraphModelInterface);
	void graphDidSync();
}

mixin template GraphEventListenerImplementation() {
	void graphWillSync() {}
	void modelWillSave(GraphModelInterface) {}
	void modelDidSave(GraphModelInterface) {}
	void modelWillDelete(GraphModelInterface) {}
	void modelDidDelete(GraphModelInterface) {}
	void graphDidSync() {}
}