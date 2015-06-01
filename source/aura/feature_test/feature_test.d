module aura.feature_test.feature_test;

debug (featureTest) {
	import colorize;
	
	import core.exception;
	import std.stdio;
	import std.string;
	import std.conv;
	import std.random;
	
	struct FeatureTestRunner {
		struct Failure {
			string feature;
			string scenario;
			Throwable detail;
		}
		
		static randomize = true;
		static uint featuresTested;
		static uint scenariosPassed;
		static uint scenariosFailed;
		static FeatureTest[] features;
		static Failure[] failures;
		
		static this() {
			writeln("Feature Testing Enabled!".color(fg.light_green));
		}
		
		static ~this() {
			if (randomize) {
				logln("Randomizing Tests".color(fg.light_cyan));
				features.randomShuffle;
			}
			foreach(feature; features) feature.run;
			writeln(this.toString);
		}
		
		static @property scenariosTested() {
			return scenariosPassed + scenariosFailed;
		}
		
		static void incFeatures() { featuresTested += 1; }
		static void incPassed() { scenariosPassed += 1; }
		static void incFailed() { scenariosFailed += 1; }
		
		static void reset() {
			featuresTested = 0;
			scenariosPassed = 0;
			scenariosFailed = 0;
			failures = [];
		}
		
		static string toString() {
			string output;
			
			if (failures.length) {
				output ~= "\n!!! Failures !!!\n\n".color(fg.light_red);
				foreach(failure; failures) {
					output ~= format("%s %s\n", "Feature:".color(fg.light_yellow), failure.feature.color(fg.light_white, bg.init, mode.bold));
					output ~= format("\t%s\n".color(fg.light_red), failure.scenario);
					output ~= format("\t%s(%s)\n".color(fg.cyan), failure.detail.file, failure.detail.line);
					output ~= format("\t%s\n\n", failure.detail.msg);
				}
			}
			else {
				output ~= "All feature tests passed successfully!\n".color(fg.light_green);
			}
			
			output ~= format(" Features tested: %s\n", featuresTested.to!string.color(fg.light_yellow));
			output ~= format("Scenarios tested: %s\n", scenariosTested.to!string.color(fg.light_yellow));
			if (scenariosPassed) output ~= format("Scenarios passed: %s\n", scenariosPassed.to!string.color(fg.light_green));
			if (scenariosFailed) output ~= format("Scenarios failed: %s\n", scenariosFailed.to!string.color(fg.light_red));
			
			return output;
		}
		
		
		// Functions for indenting output appropriately;
		
		static @property ref uint indent() {
			return _indent;
		}
		
		static void log(T)(T output) {
			auto indentString = indentTabs;
			output = output.wrap(_displayWidth, indentString, indentString, indentString.length);
			write(output.stripRight);
		}
		
		static void logln(T)(T output) {
			auto indentString = indentTabs;
			output = output.wrap(_displayWidth, indentString, indentString, indentString.length);
			write(output);
		}
		
		static void logf(T, A ...)(T fmt, A args) {
			auto output = format(fmt, args);
			log(output);
		}
		
		static void logfln(T, A ...)(T fmt, A args) {
			logf(fmt, args);
			writeln();
		}
		
		static void info(A ...)(string fmt, A args) {
			logfln(fmt.color(fg.light_blue), args);
		}
		
	private:
		// For display purposes
		static uint _indent; // Holds the current level of indentation
		static enum _tabString = "    ";
		static _displayWidth = 80;
		
		static @property string indentTabs() {
			string tabs;
			for(uint count = 0; count < _indent; ++count) tabs ~= _tabString;
			return tabs;
		}
	}
	
	alias FTImplementation = void delegate(FeatureTest);
	alias FTDelegate = void delegate();
	
	struct FeatureTestScenario {
		string name;
		FTDelegate implementation;
	}
	
	class FeatureTest {
		alias info = FeatureTestRunner.info;
		
		@property ref string name() { return _name; }
		@property ref string description() { return _description; }
		
		final void beforeAll(FTDelegate d) {
			_beforeAllCallbacks ~= d;
		}
		
		final void beforeEach(FTDelegate d) {
			_beforeEachCallbacks ~= d;
		}
		
		final void afterEach(FTDelegate d) {
			_afterEachCallbacks ~= d;
		}
		
		final void afterAll(FTDelegate d) {
			_afterAllCallbacks ~= d;
		}
		
		// To be overridden 
		void beforeAll() {
		}
		
		// To be overridden 
		void beforeEach() {
		}
		
		// To be overridden 
		void afterEach() {
		}
		
		// To be overridden 
		void afterAll() {
		}
		
		void run() {
			FeatureTestRunner.incFeatures;
			
			FeatureTestRunner.logfln("%s %s", "Feature:".color(fg.light_yellow), name.color(fg.light_white, bg.init, mode.bold));
			++FeatureTestRunner.indent;
			
			if (description.length) {
				writeln();
				FeatureTestRunner.logln(description);
				writeln();
			}
			
			_beforeAll();
			foreach(scenario; _scenarios) {
				bool scenarioPass = true;
				
				_beforeEach;
				FeatureTestRunner.logf("%s".color(fg.light_white, bg.init, mode.bold), scenario.name);
				write("  ");
				++FeatureTestRunner.indent;
				try {
					scenario.implementation();
				}
				catch (Throwable t) {
					writeln("[ FAIL ]".color(fg.black, bg.light_red));
					scenarioPass = false;
					FeatureTestRunner.incFailed;
					FeatureTestRunner.failures ~= FeatureTestRunner.Failure(name, scenario.name, t);
					
					// Rethrow the original error if it's not an assertion
					auto assertion = cast(AssertError)t;
					if (!assertion) throw t;
				}
				
				if (scenarioPass) {
					writeln("[ PASS ]".color(fg.black, bg.light_green));
					FeatureTestRunner.incPassed;
				}
				--FeatureTestRunner.indent;
				_afterEach;
			}
			_afterAll;
			--FeatureTestRunner.indent;
			writeln();
		}
		
		void scenario(string name, FTDelegate implementation) {
			_scenarios ~= FeatureTestScenario(name, implementation);
		}
		
	private:
		string _name;
		string _description;
		
		FeatureTestScenario[] _scenarios;
		FTDelegate[] _beforeEachCallbacks, _afterEachCallbacks, _beforeAllCallbacks, _afterAllCallbacks;
		
		void runCallbacks(FTDelegate[] callbacks) {
			foreach(callback; callbacks) callback();
		}
		
		void _beforeAll() {
			beforeAll;
			runCallbacks(_beforeAllCallbacks);
		}
		
		void _beforeEach() {
			beforeEach;
			runCallbacks(_beforeEachCallbacks);
		}
		
		void _afterEach() {
			afterEach;
			runCallbacks(_afterEachCallbacks);
		}
		
		void _afterAll() {
			afterAll;
			runCallbacks(_afterAllCallbacks);
		}
	}
	
	void feature(T = FeatureTest)(string name, string description, FTImplementation implementation) {
		auto f = new T();
		f.name = name;
		f.description = description;
		implementation(f);
		FeatureTestRunner.features ~= f;
	}
	
	void feature(T = FeatureTest)(string name, FTImplementation implementation) {
		feature!T(name, "", implementation);
	}
	
}
