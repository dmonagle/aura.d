module aura.queues.RedisLock;

import vibe.db.redis.redis;

// Wraps a Redis set that can allows locking of individual values
struct RedisLock {
	this(string redisKey, RedisDatabase database) {
		_redisKey = redisKey;
		_database = database;
	}

	void lock(T)(T id, scope void delegate() success = null, scope void delegate() fail = null) {
		if (_database.sadd(_redisKey, id)) {
			scope(exit) {
				if (success != null) success();
				_database.srem(_redisKey, id);
			}
		}
		else {
			if (fail != null) fail();
		}

	}

	void destroy() {
		_database.del(_redisKey);
	}


private:
	string _redisKey;
	RedisDatabase _database;
}

unittest {
	auto redisClient = new RedisClient();
	auto db = redisClient.getDatabase(0);

	auto l = RedisLock("unittest/lockTest", db);
	l.destroy;

	int firstLock;
	int secondLock;
	int thirdLock;

	l.lock("lock1", () {
		firstLock = 10;
		l.lock("lock2", () {
			secondLock = 20;
		});
		assert(secondLock == 20);
		l.lock("lock1", null, () {
			thirdLock = 30;
		});
		assert(thirdLock == 30);
	});

	assert(firstLock == 10);
}