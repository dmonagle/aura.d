module aura.queues.ModelQueue;

import vibe.d;
import std.conv;
import colorize;
import std.array;

class ModelQueue(Model) {
	@property ref bool processing() { return _processing; }
	@property ref Model[] queue() { return _queue; }
	
	this(ulong workerCount = 5) {
		_workerCount = workerCount;
		processing = false;
	}

	@property ulong workerCount() const {
		return _workerCount;
	}
	
	@property ulong workersBusy() const {
		return _workersBusy;
	}

	@property bool workersAvailable() const {
		return workersBusy < workerCount;
	}
	
	@property ulong length() const {
		return _queue.length;
	}
	
	void modelWorker() {
		while (_processing || !_queue.empty) {
			if (!_queue.empty) {
				_workersBusy++;
				auto model = queue.front;
				queue.popFront();
				logInfo("%s worker: Queue: %s Processing: %s".color(fg.light_magenta), Model.stringof, queue.length, model.to!string);

				try {
					_modelAction(model);
				}
				catch (Exception e) {
					logError("While processing queue: %s".color(fg.light_red), e.msg);
				}
				_workersBusy--;
			} 
			else {
				sleep(2.seconds);
			}
		}
		logInfo("%s worker finishing".color(fg.magenta), Model.stringof);
	}
	
	void start(void delegate(Model model) modelAction) {
		if (!_processing) {
			_processing = true;
			_modelAction = modelAction;
			foreach (i; 0 .. _workerCount) _tasks ~= runTask(&modelWorker);
		}
	}
	
	void join() {
		processing = false;
		foreach (t; _tasks) t.join();
	}
private:
	bool _processing;
	ulong _workerCount;
	ulong _workersBusy;
	
	Task[] _tasks;
	Model[] _queue;
	scope void delegate(Model model) _modelAction;
}