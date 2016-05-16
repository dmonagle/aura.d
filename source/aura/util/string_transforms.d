module aura.util.string_transforms;

import std.uni;
import std.algorithm;

/*
 * This precomiled regex version does not work at compile time as regex uses malloc
string snakeCase(const string input) {
	static auto firstCapRE = ctRegex!(`(.)([A-Z][a-z]+)`);
	static auto allCapRE = ctRegex!(`([a-z0-9])([A-Z])`, "g");
	
	string output = input.replace(firstCapRE, `$1_$2`);
	output = output.replace(allCapRE, `$1_$2`);
	
	return output.toLower;
}
*/

/// Returns the snake cased version of a string. It has no effect on an already
string snakeCase(const string input) {
	string firstPass(const string input) {
		if (input.length < 3) return input;
		
		string output;
		for(auto index = 2; index < input.length; index++) {
			output ~= input[index - 2];
			if (input[index - 1].isUpper && input[index].isLower)
				output ~= "_";
		}
		
		return output ~ input[$-2..$];
	}

	string secondPass(const string input) {
		if (input.length < 2) return input;
		
		string output;
		for(auto index = 1; index < input.length; index++) {
			output ~= input[index - 1];
			if (input[index].isUpper && (input[index-1].isLower || input[index-1].isNumber))
				output ~= "_";
		}
		
		return output ~ input[$-1..$];
	}

	if (input.length < 2) return input.toLower;

	string output = firstPass(input);
	output = secondPass(output);

	return output.toLower;
}


unittest {
	assert("C".snakeCase == "c");
	assert("cA".snakeCase == "c_a");
	assert("Ca".snakeCase == "ca");
	assert("Camel".snakeCase == "camel");
	assert("CamelCase".snakeCase == "camel_case");
	assert("CamelCamelCase".snakeCase == "camel_camel_case");
	assert("Camel2Camel2Case".snakeCase == "camel2_camel2_case");
	assert("getHTTPResponseCode".snakeCase == "get_http_response_code");
	assert("get2HTTPResponseCode".snakeCase == "get2_http_response_code");
	assert("HTTPResponseCode".snakeCase == "http_response_code");
	assert("HTTPResponseCodeXYZ".snakeCase == "http_response_code_xyz");
}

/// Returns the camelcased version of the input string. 
string camelCase(const string input, bool upper = false, dchar[] separaters = ['_']) {
	string output;
	bool upcaseNext = upper;
	foreach(c; input) {
		if (!separaters.canFind(c)) {
			if (upcaseNext) {
				output ~= c.toUpper;
				upcaseNext = false;
			}
			else
				output ~= c.toLower;
		}
		else {
			upcaseNext = true;
		}
	}

	return output;
}

string camelCaseUpper(const string input) {
	return camelCase(input, true);
}

string camelCaseLower(const string input) {
	return camelCase(input, false);
}

unittest {
	assert("c".camelCase == "c");
	assert("c".camelCase(true) == "C");
	assert("c_a".camelCase == "cA");
	assert("ca".camelCase(true) == "Ca");
	assert("camel".camelCase(true) == "Camel");
	assert("Camel".camelCase(false) == "camel");
	assert("camel_case".camelCase(true) == "CamelCase");
	assert("camel_camel_case".camelCase(true) == "CamelCamelCase");
	assert("caMel_caMel_caSe".camelCase(true) == "CamelCamelCase");
	assert("camel2_camel2_case".camelCase(true) == "Camel2Camel2Case");
	assert("get_http_response_code".camelCase == "getHttpResponseCode");
	assert("get2_http_response_code".camelCase == "get2HttpResponseCode");
	assert("http_response_code".camelCase(true) == "HttpResponseCode");
	assert("http_response_code_xyz".camelCase(true) == "HttpResponseCodeXyz");
}
