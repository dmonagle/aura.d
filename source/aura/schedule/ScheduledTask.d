module aura.schedule.ScheduledTask;

import vibe.core.task;
import vibe.core.core;

import std.datetime;
import std.typecons;

struct ScheduledTaskMeta {
	int runCount;
	Nullable!SysTime lastRun;
	Nullable!SysTime nextRun;
}

struct ScheduledTask {
	alias NextTimeFunction = SysTime delegate(ScheduledTaskMeta);
	alias TaskFunction = void delegate(ScheduledTaskMeta);

	this(TaskFunction t, NextTimeFunction nt) {
		task = t;
		nextTime = nt;
	}

	@property void task(void delegate(ScheduledTaskMeta) t) { _taskFunction = t; }
	@property void nextTime(SysTime delegate(ScheduledTaskMeta) nt) { _nextTimeFunction = nt; }

	@property bool taskRunning() const {
		if (!_task) return false;
		return _task.running;
	}

	void setTimerForNextRun() {
		_meta.nextRun = _nextTimeFunction(_meta);

		auto duration = _meta.nextRun - Clock.currTime;
		_timer = setTimer(duration, &run);
	}

	void start() {
		assert(_nextTimeFunction, "No nextTime is set for ScheduledTask");
		assert(_taskFunction, "No task is set for ScheduledTask");

		setTimerForNextRun;
	}

	void stop() {
		_timer = Timer.init;
		if (taskRunning) _task.join;
	}

private:
	void run() {
		if (taskRunning) return;

		_task = runTask!ScheduledTaskMeta(_taskFunction, _meta);
		_meta.lastRun = Clock.currTime;
		_meta.runCount++;
		setTimerForNextRun;
	}

	Timer _timer;
	Task _task;
	ScheduledTaskMeta _meta;

	TaskFunction _taskFunction;
	NextTimeFunction _nextTimeFunction;
}

debug (auraSchedule) {
	unittest {
		import core.time;

		import std.stdio;
		import colorize;
		
		auto t = ScheduledTask(
			(meta) {
				writefln("Hello %s".color(fg.light_green), meta.runCount);

			},
			(meta) {
				return Clock.currTime + 5.seconds;
			}
		);

		writeln("Running task ...".color(fg.light_cyan));
		t.start();
		sleep(30.seconds);
		t.stop();
	}
}
