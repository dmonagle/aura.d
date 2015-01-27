module aura.queues.redis_locks;

import vibe.db.redis.redis;
import std.datetime;
import std.conv;
import std.random;

struct RedisLockBase(bool scopedUnlock = false) {
	this(RedisDatabase database, string redisKey, Duration expiryTime = 2.seconds) {
		_redisKey = redisKey;
		_database = database;
		_expiryTime = expiryTime;
	}
	
	@property int id() const {
		return _lockId;
	}
	
	bool locked() {
		return _database.exists(_redisKey);
	}
	
	bool lock() {
		return tryLock;
	}
	
	void lock(scope void delegate() success = null, scope void delegate() fail = null) {
		if (tryLock) {
			scope(exit) {
				forceUnlock;
			}
			if (success != null) success();
		}
		else {
			if (fail != null) fail();
		}
		
	}
	
	bool unlock() {
		if (mine) {
			forceUnlock;
			return true;
		}
		return false;
	}

	void forceUnlock() {
		_database.del(_redisKey);
	}
	
	bool touch(Duration expiryTime) {
		if (mine) {
			if (expiryTime == Duration.zero) 
				_database.persist(_redisKey);
			else 
				_database.expire(_redisKey, _expiryTime);
			return true;
		}
		return false;
	}
	
	bool touch() {
		return touch(_expiryTime);
	}
	
	int activeLockId() {
		auto result = _database.get(_redisKey);
		if (!result.length) return 0;
		return result.to!int;
	}
	
	// Returns true if the lock is held by this struct
	bool mine() {
		if (_lockId && (activeLockId == _lockId)) return true;
		return false;
	}

	static if (scopedUnlock) {
		~this() {
			import std.stdio;
			// Only remove the lock if it was locked by this instance
			unlock();
		}
	}

	
private:
	RedisDatabase _database;
	string _redisKey;
	int _lockId;
	Duration _expiryTime;
	
	bool tryLock() {
		if (!_lockId) _lockId = uniform(1, int.max);
		if (_database.setNX(_redisKey, _lockId.to!string, _expiryTime)) {
			return true;
		}
		return false;
	}


}

alias RedisLock = RedisLockBase!(false);

version (redis_unittest) {
	unittest {
		auto redisClient = new RedisClient("redis");
		auto db = redisClient.getDatabase(0);
		
		if (true) {
			auto l = RedisLock(db, "unittest/lockTest1");
			assert(l.lock());
			assert(l.locked);
			assert(l.mine); 
		}
		
		// Previous lock should be valid from outside scope
		auto l = RedisLock(db, "unittest/lockTest1");
		assert(l.locked);
		assert(!l.lock);
		assert(!l.mine);
		assert(!l.unlock); // Can't call unlock as this struct didn't create the lock
		assert(l.locked);
		l.forceUnlock; // It can be forced though
		assert(!l.locked);
	}
}

alias RedisScopedLock = RedisLockBase!(true);

version (redis_unittest) {
	unittest {
		auto redisClient = new RedisClient("redis");
		auto db = redisClient.getDatabase(0);

		if (true) {
			auto l = RedisScopedLock(db, "unittest/lockTest1");
			assert(l.lock());
			assert(l.locked);
			assert(l.mine); 

			auto l2 = RedisScopedLock(db, "unittest/lockTest1");
			assert(!l2.lock()); // Lock should fail as it uses the same key as the previous lock
			assert(l2.locked); // It should still be locked however
			assert(!l2.mine); // But the lock doesn't belong to this struct
		}

		// Previous locks should be released after they go out of scope
		auto l = RedisScopedLock(db, "unittest/lockTest1");
		assert(!l.locked);
		assert(l.lock);
	}

	// Test the lambda version
	unittest {
		auto redisClient = new RedisClient("redis");
		auto db = redisClient.getDatabase(0);

		auto l = RedisScopedLock(db, "unittest/lockTest");

		bool firstLock;
		bool secondLockFail;

		l.lock(() {
			firstLock = true;
			l.lock(() {
				secondLockFail = false;
			},
			() {
				secondLockFail = true;
			});
		});
		assert(firstLock);
		assert(secondLockFail);
	}
}