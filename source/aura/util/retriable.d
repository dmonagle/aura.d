module aura.util.retriable;

import elasticsearch.transport.exceptions;

import vibe.d;

import core.time;
import std.algorithm;

enum DEFAULT_INTERVAL = 100.msecs;
enum DEFAULT_CODES = [0, HTTPStatus.requestTimeout.to!int, HTTPStatus.gatewayTimeout.to!int]; 

struct RetryConfig {
    Duration interval = DEFAULT_INTERVAL;
    int count = 0;
    int[] retryCodes = DEFAULT_CODES;
}

class Retriable {
    RetryConfig retryConfig;

    this(RetryConfig config = RetryConfig()) {
        retryConfig = config;
    }

    /// Returns true if the request was successfully completed
    bool request(E = RequestException)(void delegate() action, bool delegate(E) isRetriable) {
        auto retryMax = (retryConfig.count == 0) ? 1 : retryConfig.count;
        
        for(int retry; retry < retryMax; retry++) {

            try {

                if (retry > 0)
                    sleep(retryConfig.interval);

                action();                

                return true;    // action was successfully completed

            } catch (E e) {
                logInfo(e.msg);

                if (isRetriable(e)) continue;

                break;
            }
        }

        return false;   // action was failed to complete
    }

    /// Returns true if the request was successfully completed
    bool request(E = RequestException)(void delegate() action) {

        return request!E(action, (e) {

            //  exception thrown 
            if (retryConfig.retryCodes.canFind(e.response.status)) {
                return true;    // retriable response code
            }

            return false;   // don't retry
        });
    }

    /// Asynchronous retry with retryCodes
    void asyncRequest(E = RequestException)(void delegate() action) {
        runTask(() {
            request!E(action);
        });
    }

    /// Asynchronous retry with isRetriable() callback
    void asyncRequest(E = RequestException)(void delegate() action, bool delegate(E) isRetriable) {
        runTask(() {
            request!E(action, isRetriable);
        });
    }
}

unittest {
    import aura.query.elasticsearch;
	import elasticsearch;

    static int triedCount;

    // action to be retried
    string action() {
        triedCount++;
        
        if (triedCount < 5) {
            Response response;
            throw new RequestException(null, RequestMethod.PUT, "xyz/test", ESParams(), "request body", response);
        }
        return "completed";
    }

    bool success;
    string result;
    Retriable retriable;
    
    // Successfull retry
    success = false; triedCount = 0; result = "";
    retriable = new Retriable(RetryConfig(10.msecs, 6));
    success = retriable.request(() {
        result = action;
    });

    assert(triedCount == 5);
    assert(success == true);
    assert(result == "completed");

    // Successfull retry edge case
    success = false; triedCount = 0; result = "";
    retriable = new Retriable(RetryConfig(10.msecs, 5));
    success = retriable.request(() {
        result = action;
    });

    assert(triedCount == 5);
    assert(success == true);
    assert(result == "completed");

    // max retry reached
    success = false; triedCount = 0; result = "";
    retriable = new Retriable(RetryConfig(10.msecs, 3));
    success = retriable.request(() {
        result = action;
    });

    assert(triedCount == 3);
    assert(success == false);
    assert(result == "");

    // Without retry (retryConfig.count = 0)
    success = false; triedCount = 0; result = "";
    retriable = new Retriable(RetryConfig(10.msecs, 0));
    success = retriable.request(() {
        result = action;
    });

    assert(triedCount == 1);
    assert(success == false);
    assert(result == "");

    // Without retryConfig
    success = false; triedCount = 0; result = "";
    retriable = new Retriable;
    success = retriable.request(() {
        result = action;
    });

    assert(triedCount == 1);
    assert(success == false);
    assert(result == "");    
}