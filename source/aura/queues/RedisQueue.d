module aura.queues.RedisQueue;

import std.typecons;
import vibe.db.redis.redis;

/// A Redis based FIFO queue that will only accept unique values
struct RedisQueue {
	@property string listKey() const {
		return _redisKey ~ "/list";
	}

	@property string listLockKey() const {
		return _redisKey ~ "/lock";
	}
	
	@property string processingLockKey() const {
		return _redisKey ~ "/plock";
	}

	@property long length() {
		return _database.llen(listKey);
	}
	
	bool push(T)(T id) {
		if (_database.sadd(listLockKey, id)) {
			_database.rpush(listKey, id);
			return true;
		}
		return false;
	}

	Nullable!string pop() {
		Nullable!string returnString = _database.lpop!(Nullable!string)(listKey);
		if (!returnString.isNull) {
			_database.srem(listLockKey, returnString);
		}
		return returnString;
	}

	/// Clears the queue by removing the keys from the database
	void clear() {
		_database.del(listKey, listLockKey);
	}

	this(string queueName, RedisDatabase database) {
		_redisKey = queueName;
		_database = database;
	}

private:
	RedisDatabase _database;
	string _redisKey;
}

unittest {
	auto redisClient = new RedisClient();
	auto db = redisClient.getDatabase(0);

	auto q = RedisQueue("unittest/testQueue", db);
	q.clear;
	assert(q.length == 0);
	assert(q.pop.isNull);
	assert(q.push("one"));
	assert(q.length == 1);
	assert(!q.push("one"));
	assert(q.length == 1);
	assert(q.push("two"));
	assert(q.length == 2);
	assert(q.pop() == "one");
	assert(q.length == 1);
	assert(q.pop() == "two");
	assert(q.length == 0);
	assert(q.pop.isNull);
	q.clear;
}

import aura.queues.redis_locks;
import vibe.core.core;
import std.datetime;
import std.conv;

struct RedisProcessingQueue {
	this(RedisDatabase database, string queueName, Duration queueDuration = 24.hours, string processingLockKey = "") {
		_redisKey = queueName;
		_pLockKey = processingLockKey.length ? processingLockKey : _redisKey ~ "/plock";
		_database = database;
		_requeueTimeout = 10.seconds;
		_queueDuration = queueDuration;
		_processingLockDuration = 2.minutes;
	}

	@property string name() const {
		return _redisKey;
	}

	@property string listKey() const {
		return _redisKey ~ "/list";
	}
	
	@property string listLockKey(T)(T id) const {
		return _redisKey ~ "/llock/" ~ id.to!string;
	}
	
	@property string processingLockKey(T)(T id) const {
		return _pLockKey ~ "/" ~ id.to!string;
	}
	
	@property long length() {
		return _database.llen(listKey);
	}

	// Clears the queue by removing the queue list and all of the list locks. This does not clear the processing locks
	void clear() {
		_database.del(listKey);
		auto keys = _database.keys(_redisKey ~ "/llock/*");
		foreach(key; keys) {
			_database.del(key);
		}
	}

	void forcePush(string id) {
		auto listLock = RedisLock(_database, listLockKey(id), _queueDuration);
		listLock.forceUnlock;
		push(id);
	}

	bool push(string id) {
		auto listLock = RedisLock(_database, listLockKey(id), _queueDuration);

		if (listLock.lock()) {
			_database.rpush(listKey, id);
			return true;
		}
		return false;
	}
	
	bool process(scope void delegate(string) action = null) {
		Nullable!string returnString = _database.lpop!(Nullable!string)(listKey); 
		if (returnString.isNull) return false;
		auto id = returnString.get;
		auto lLock = RedisLock(_database, listLockKey(id));
		lLock.touch(_requeueTimeout + 2.seconds); // Now if anything happens to prevent requeuing, the list lock will expire by itself.


		auto pLock = RedisScopedLock(_database, processingLockKey(id), _processingLockDuration); // Attempt to get a processing lock
		try {
			if (pLock.lock) {
				lLock.forceUnlock; // Force unlock of list lock. As this struct didn't create it, force is required
				action(id);

				return true; // Processing Lock will be freed automatically
			}
			else {
				// We add the id back to the queue after the requeue timeout
				setTimer(_requeueTimeout, () {
					_database.rpush(listKey, id);
					lLock.touch(); // Set the listLock back to the default value
				});
				return false;
			}
		}
		catch (Exception e) {
			// This error perhaps shouldn't be caught. It normally means a redis issue
		}

		return false;
	}

private:
	RedisDatabase _database;
	string _redisKey;
	string _pLockKey;
	Duration _queueDuration;
	Duration _requeueTimeout;
	Duration _processingLockDuration;

	Task[] _tasks;

}

unittest {
	auto redisClient = new RedisClient();
	auto db = redisClient.getDatabase(0);
	
	auto queue = RedisProcessingQueue(db, "unittest/testQueue");
	queue.clear();

	assert(queue.push("one"));
	assert(!queue.push("one"), "Managed to add a second copy of an id already in the queue");
	queue.process((id) {
	});
}

import vibe.core.log;
import colorize;

struct RedisWorkerQueue {
	this(RedisDatabase database, string queueName, Duration queueDuration = 24.hours, string processingLockKey = "") {
		_queue = RedisProcessingQueue(database, queueName, queueDuration, processingLockKey);
	}

	void worker() {
		while (_processing) {
			if (!_queue.process((id) {
				_workersBusy++;
				logInfo("Worker: %s Queue size: %s Processing: %s".color(fg.light_magenta), queue.name, _queue.length, id);
				
				try {
					_action(id);
				}
				catch (Exception e) {
					logError("While processing id: %s for queue %s: %s".color(fg.light_red), id, queue.name, e.msg);
				}
				_workersBusy--;
				logInfo("Queue item finished");
			})) sleep(200.msecs);
		}
		logInfo("Worker finishing".color(fg.magenta));
	}
	
	void runWorkers(scope void delegate(string) action, ulong workerCount) {
		if (!_processing) {
			_processing = true;
			_action = action;
			foreach (i; 0 .. workerCount) _tasks ~= runTask(&worker);
		}
	}

	bool push(string id) {
		return queue.push(id);
	}

	void join() {
		_processing = false;
		foreach (t; _tasks) t.join();
	}

	@property ref RedisProcessingQueue queue() {
		return _queue;
	}

	// Clears the underlying RedisProcessingQueue
	void clear() {
		_queue.clear;
	}

private:
	bool _processing;
	//ulong _workerCount;
	ulong _workersBusy;
	
	Task[] _tasks;
	RedisProcessingQueue _queue;
	void delegate(string) _action;
}

// This unit test is commented out by default as it takes significant time to run. Should probably be run based on a version
/*
unittest {
	import std.stdio;
	import colorize;

	writeln("Starting test".color(fg.light_blue));

	auto redisClient = new RedisClient();
	auto db = redisClient.getDatabase(0);

	auto queue = RedisWorkerQueue(db, "unittest/testQueue");
	queue.clear;
	queue.runWorkers((id) {
		writeln("Processing ID: " ~ id);
		sleep(20.seconds);
	}, 2);

	writeln("Queue has been created. Pushing in 3 seconds".color(fg.light_green));
	sleep(3.seconds);
	assert(queue.push("one"));
	sleep(2.seconds);
	assert(queue.push("two"));
	sleep(2.seconds);
	// This should add but should fail to process immediately as it should still be processing
	assert(queue.push("two"));
	// The following should queue up
	assert(queue.push("three"));
	assert(queue.push("four"));
	// These should refuse to add as they are already in the queue
	assert(!queue.push("three"));
	assert(!queue.push("four"));

	writeln("Finished pushing".color(fg.cyan));
	sleep(240.seconds);
	queue.join();

	writeln("Finishing test".color(fg.light_blue));

}
*/