module aura.queues.ModelRedisQueue;

import vibe.d;
import colorize;

import aura.queues.RedisQueue;
import aura.queues.ModelQueue;

// Monitors a RedisQueue for model Ids and adds the model to an underlying ModelQueue
class ModelRedisQueue(T, alias pred = null) {
	this(string redisKey, RedisDatabase database) {
		_database = database;
		_redisKey = redisKey;
		_redisQueue = RedisQueue(_redisKey, _database);
		_modelQueue = new ModelQueue!T;
		runTask(&runQueue);
	}
	
private:
	void runQueue() {
		scope(exit) {
			logInfo("Stopping %s(%s) queue".color(fg.light_red), _redisKey, T.stringof);
		}
		logInfo("Starting %s(%s) queue".color(fg.light_green), _redisKey, T.stringof);
		_modelQueue.start((T model) {
			logDebug(model._id.toString.color(fg.yellow));
			static if (!is(typeof(pred) == typeof(null))) pred(model);
			sleep(3.seconds);
		});
		
		while (true) {
			// If there is anything in the redisQueue and there are available workers
			while (_redisQueue.length && _modelQueue.workersAvailable) {
				auto id = _redisQueue.pop;
				if (!id.isNull) {
					BsonObjectID bId;
					try {
						bId = BsonObjectID.fromString(id);
						auto model = T.findModel(bId);
						if (model) _modelQueue.queue ~= model;
					}
					catch (Exception e) {
						logError(T.stringof ~ " push queue id '%s': %s".color(fg.light_red), id, e.msg);
					}
				}
			}
			sleep(2.seconds);
		}
	}
	
	string _redisKey;
	RedisDatabase _database;
	RedisQueue _redisQueue;
	ModelQueue!T _modelQueue;
}
