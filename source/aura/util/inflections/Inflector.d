module aura.util.inflections.Inflector;

import std.regex;
import std.array;
import std.algorithm;
import std.uni;

interface InflectionInterface {
	string inflect(const string input);
	bool matches(const string input) const;
}

class InflectionRule(string expression, string format, string matchOptions = "") : InflectionInterface {
	private static auto _regex = ctRegex!(expression, matchOptions);

	static InflectionInterface opCall() {
		return cast(InflectionInterface)(new InflectionRule!(expression, format, matchOptions));
	}

	override string inflect(const string input) {
		return input.replaceFirst(_regex, format);
	}
	
	bool matches(const string input) const {
		return cast(bool)input.matchFirst(_regex);
	}
}

unittest {
	auto testInflector = InflectionRule!(`$`, `s`, "i")();
	assert (testInflector.inflect("apple") == "apples");
}

struct Translation {
	string singular;
	string plural;
}

class Inflector {
	static InflectionInterface[] _plurals;
	static InflectionInterface[] _singulars;
	static Translation[] _irregulars;
	static string[] _uncountables;

	static void plural(string expression, string format, string matchOptions = "")() {
		_plurals ~= InflectionRule!(expression, format, matchOptions)();
	}
	
	static void singular(string expression, string format, string matchOptions = "")() {
		_singulars ~= InflectionRule!(expression, format, matchOptions)();
	}

	static void irregular(string singular, string plural) {
		_irregulars ~= Translation(singular, plural);
	}
	
	static void uncountable(string[] values ...) {
		_uncountables ~= values;
	}
	
	static string transform(bool plural)(const string input) {
		static if (plural) {
			alias _transforms = _plurals;
		}
		else {
			alias _transforms = _singulars;
		}

		auto lowerInput = input.toLower;

		if (_uncountables.canFind(lowerInput)) return input;

		foreach(irregular; _irregulars) {
			static if (plural) {
				if (lowerInput == irregular.singular) return irregular.plural;
			}
			else {
				if (lowerInput == irregular.plural) return irregular.singular;
			}
		}

		foreach(rule; _transforms) {
			if (rule.matches(input)) 
				return rule.inflect(input);
		}
		
		return input;
	}

	alias pluralize = transform!true;
	alias singularize = transform!false;
}
