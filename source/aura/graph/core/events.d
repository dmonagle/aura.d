module aura.graph.core.events;

import aura.graph.core;

interface GraphEventListener : GraphInstanceInterface {
	void graphWillSync();
	void modelWillSave(GraphModelInterface);
	void modelDidSave(GraphModelInterface);
	void modelWillDelete(GraphModelInterface);
	void modelDidDelete(GraphModelInterface);
	void graphDidSync();
}

mixin template GraphEventListenerImplementation() {
	mixin GraphInstanceImplementation;

	void graphWillSync() {}
	void modelWillSave(GraphModelInterface) {}
	void modelDidSave(GraphModelInterface) {}
	void modelWillDelete(GraphModelInterface) {}
	void modelDidDelete(GraphModelInterface) {}
	void graphDidSync() {}
}