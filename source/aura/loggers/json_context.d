module aura.loggers.json_context;

import vibe.d;
import aura.data.json;

import std.uuid;
import std.stdio;
import std.regex;

struct LoggerContext {
    Json context;
    string taskId;
    
    bool valid() {
        return taskId.length > 0;
    }
    
    void reset() {
        context = Json.emptyObject;
        taskId = randomUUID().to!string;
    }
    
    void addContext(T)(string key, T value) {
        context[key] = value;
    }
    
    void removeContext(string key) {
        context.remove(key);
    }
    
    void withContext(T)(string key, T value, void delegate() process) {
        addContext(key, value);
        process();
        removeContext(key);
    }
}

/**
    Logger implementation for logging to Json
*/
final class JsonContextLogger : Logger {
	this(string baseFileName = "logs/vibe") {
		_baseFileName = baseFileName;
	}

	@property void minLogLevel(vibe.core.log.LogLevel value) pure nothrow @safe { this.minLevel = value; }
	
	override void log(ref LogLine msg)
		@trusted // ???
	{
		import std.regex;

		auto logDate = cast(Date)msg.time;
		if (_lastDate.isNull || _lastDate != logDate) {
			openLogForToday(logDate);
		}


		if( !_logFile.isOpen ) return;
		auto logJson = msg.serializeToJson;
		logJson["logLevel"] = msg.level.to!string;
        if (_context.valid) {
            logJson["taskId"] = _context.taskId;
            logJson.jsonMerge(_context.context);
        }
		try {
			// If the msg text is a JSON string then we break out the keys and add them directly to the logJson
			auto messageJson = parseJsonString(msg.text);
			logJson.remove("text");
			foreach(string key, value; messageJson) {
				// Clean string keys of ANSI codes
				if (isString(value)) value = Json(value.get!string.stripANSI);
				logJson[key] = value;
			}
		}
		catch (JSONException e) {
			// Clean the text of ANSI codes
			logJson["text"] = msg.text.stripANSI;
		}

		_logFile.writeln(logJson.toString);
		_logFile.flush;
	}

	void openLogForToday(Date date = cast(Date)Clock.currTime) {
		import std.format;
		_logFile = File(format("%s-%s.log", _baseFileName, date.toISOExtString), "a");

	}
    
    
    @property static ref auto context() { return _context; }
    static void resetContext() { _context.reset; }

    alias context this;

private:
    static TaskLocal!LoggerContext _context;

	File _logFile;
	Nullable!Date _lastDate;
	string _baseFileName;
}

protected string stripANSI(string input) {
    auto matchANSI = ctRegex!(`[\u001b\u009b][\[\(\)#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]`);
    return input.replaceAll(matchANSI, "");
}
