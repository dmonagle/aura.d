module aura.queues.RedisQueue;

import std.typecons;
import vibe.db.redis.redis;

/// A Redis based FIFO queue that will only accept unique values
struct RedisQueue {
	@property string setName() const {
		return _redisKey ~ "/queueSet";
	}
	
	@property string listName() const {
		return _redisKey ~ "/queueList";
	}

	@property long length() {
		return _database.llen(listName);
	}
	
	bool push(T)(T id) {
		if (_database.sadd(setName, id)) {
			_database.rpush(listName, id);
			return true;
		}
		return false;
	}

	Nullable!string pop() {
		Nullable!string returnString = _database.lpop!(Nullable!string)(listName);
		if (!returnString.isNull) {
			_database.srem(setName, returnString);
		}
		return returnString;
	}

	void destroy() {
		_database.del(listName, setName);
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
	auto q = RedisQueue("testQueue");
	q.destroy;
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
	q.destroy;
}

