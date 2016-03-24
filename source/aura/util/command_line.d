module aura.util.commandline;

import std.string;
import std.algorithm;
import std.array;
import std.traits;
import std.stdio;
import std.conv;
import std.datetime;

///
class CommandLineException : Exception {
    this(string s) { super(s); }
}

/// Converts a string parameter to the desired type
T convertCommandLineParameter(T)(string param) {
    static if (is(T == string))
        return param;
    else static if (is(T == int))           
        return param.to!int;
    else static if (is(T == bool)) {           
        if (!param.length) return false;
        return ['T', 'Y'].canFind(param[0].toUpper);
    }
    else static if (is(T == Date)) 
    {           
        try {
            return Date.fromISOExtString(param);
        }
        catch (Exception e) {
            throw new CommandLineException("Could not convert '" ~ param ~ "' to a date");
        }
    }
    else
    {
        throw new CommandLineException("Parameter format is incorrect");
    }
}


void processCommandLine(C : Object)(C instance, string[] commands ...) {
    void printHelp() {
        writeln("There is no help for you here...");
    }
    
    if (!commands.length) {
        printHelp;
        return;
    }
    
    foreach(memberName; __traits(allMembers, C)) {
        static if (!is(typeof(__traits(getMember, Object, memberName)))) { // exclude Object's default methods and field
    		foreach (overload; MemberFunctionsTuple!(C, memberName)) {
				alias RT = ReturnType!overload;

				static if (is(RT == class) || is(RT == interface)) {
					// nested API
					static assert(
						ParameterTypeTuple!overload.length == 0,
						"Instances may only be returned from parameter-less functions ("~M~")!"
					);
                    if (commands[0] == memberName) {
                        commands.popFront;
                        processCommandLine(__traits(getMember, instance, memberName), commands);
                        return;
                    }
				} else {
                    if (commands[0] == memberName) {
                        auto parameters = commands;
                        parameters.popFront;
                        writefln("Received parameters %s", parameters);
                        
                        alias PARAMS = Parameters!overload;
                        alias DEFAULTS = ParameterDefaults!overload;
                        writefln("%s: %s%s", memberName, RT.stringof, PARAMS.stringof);
                        writefln("%s: %s%s", memberName, RT.stringof, DEFAULTS.stringof);
                        
                        PARAMS params = void;
                        foreach (i, PT; PARAMS) {
                            // Check if we have run out of parameters that there is a default;
                            if (i >= parameters.length) {
                                static if (!is(DEFAULTS[i] == void)) {
                                    auto p = DEFAULTS[i];
                                    writefln("We'll go with the default parameter %s", p);
                                    params[i].setVoid(DEFAULTS[i]);
                                }
                                else {
                                    throw new CommandLineException("Not enough parameters supplied");
                                }
                            }
                            else {
                                auto p = convertCommandLineParameter!PT(parameters[i]);
                                writefln("%s %s: %s", i, PT.stringof, p);
                                params[i].setVoid(p);
                            }
                        }
                        
                        __traits(getMember, instance, memberName)(params);
                        return;
                    }
                }
            }
        }
    }
    writefln("Unknown command: %s", commands[0]);
}

/// Credit: This was taken from vibe.web.common
/// properly sets an uninitialized variable
package void setVoid(T, U)(ref T dst, U value)
{
	import std.traits;
	static if (hasElaborateAssign!T) {
		static if (is(T == U)) {
			(cast(ubyte*)&dst)[0 .. T.sizeof] = (cast(ubyte*)&value)[0 .. T.sizeof];
			typeid(T).postblit(&dst);
		} else {
			static T init = T.init;
			(cast(ubyte*)&dst)[0 .. T.sizeof] = (cast(ubyte*)&init)[0 .. T.sizeof];
			dst = value;
		}
	} else dst = value;
}

/*
@commandLineHelp(`These are the test functions`)
class TestCommandLine {
    int hello(string name, string surname = "Nobody", int number = 10) {
        writefln("Hello there %s %s", name, surname);
        return 0;
    }
    
    void birthday(string name, Date birthday) {
        writefln("Hello %s, your birthday is on %s", name, birthday);
    }
}

@commandLineHelp(`Vibe.d Server`)
class CommandLine {
    auto test() {
        return new TestCommandLine;
    }
}

unittest {
    processCommandLine(new CommandLine, "test", "birthday", "David", "2016-04-17");
}
*/