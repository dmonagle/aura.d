module aura.queues.ModelRedisQueue;

import vibe.d;
import colorize;

import aura.queues.RedisQueue;
import aura.queues.ModelQueue;


// Monitors a RedisQueue for model Ids and adds the model to an underlying ModelQueue
class ModelRedisQueue(T) {
	this(string redisKey, RedisDatabase database, void delegate(T model) modelAction, ulong workerCount = 5) {
		_modelAction = modelAction;
		_database = database;
		_redisKey = redisKey;
		_redisQueue = RedisQueue(_redisKey, _database);
		_modelQueue = new ModelQueue!T(workerCount);
		runTask(&runQueue);
	}
	
private:
	void runQueue() {
		scope(exit) {
			logInfo("Stopping %s(%s) queue".color(fg.light_red), _redisKey, T.stringof);
		}
		logInfo("Starting %s(%s) queue".color(fg.light_green), _redisKey, T.stringof);
		_modelQueue.start(_modelAction);
		
		while (true) {
			// If there is anything in the redisQueue and there are available workers
			auto rLength =_redisQueue.length;
			while (rLength && _modelQueue.workersAvailable) {
				auto id = _redisQueue.pop;
				logDebug("Popped %s from %s(%s) queue(%s)".color(fg.light_yellow), id, _redisKey, T.stringof, rLength);
				if (!id.isNull) {
					BsonObjectID bId;
					try {
						bId = BsonObjectID.fromString(id);
						auto model = T.findModel(bId);
						if (model) _modelQueue.queue ~= model;
					}
					catch (Exception e) {
						logError(T.stringof ~ " push queue: %s".color(fg.light_red), e.msg);
					}
				}
				rLength =_redisQueue.length;
			}
			sleep(500.msecs);
		}
	}
	
	string _redisKey;
	RedisDatabase _database;
	RedisQueue _redisQueue;
	ModelQueue!T _modelQueue;
	void delegate(T model) _modelAction;
}
