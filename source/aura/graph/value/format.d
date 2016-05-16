module aura.graph.value.format;

import aura.graph.value;

import colorize;
import std.format;

struct GraphValueFormatter {
    bool pretty;
    
    string formatValue(GraphValue value) {
        _result = "";
        printValue(value);
        return _result;
    }

 private:
    string _result;
    ubyte _indent;
    bool _repressIndent;

	string tabs() {
        if (_repressIndent) {
            _repressIndent = false;
            return "";
        }
		if (!pretty) return "";
		string tabString;
		for(auto count = 0; count < _indent; ++count) tabString ~= "    ";
		return tabString;
	}
    

    void print(Char, Args...)(in Char[] fmt, Args args) {
        _result ~= tabs();
        _result ~= format(fmt, args);
    }
    
    void println(Char, Args...)(in Char[] fmt, Args args) {
        print(fmt, args);
        _result ~= "\n";
    }

    void printValue(GraphValue value) {
        if (value.isObject) {
            println("{".color(fg.light_cyan));
            _indent++;
            auto graphObject = value.get!(GraphValue.Object);
            foreach(string key, GraphValue v; graphObject) {
                print("%s: ", key);
                _repressIndent = true;
                printValue(v);
            }
            _indent--;
            println("}".color(fg.light_cyan));
        }
        else if (value.isArray) {
            println("[".color(fg.light_cyan));
            _indent++;
            foreach(GraphValue v; value) 
                printValue(v);
            _indent--;
            println("]".color(fg.light_cyan));
        }
        else {
            import std.datetime;
            auto pColor = fg.light_yellow;
            if (value.isType!string) pColor = fg.light_magenta;
            else if (value.isType!Date) pColor = fg.blue;

            println("%s".color(pColor), value);
        }
    }
}

string formatPretty(GraphValue value) {
    GraphValueFormatter formatter;
    formatter.pretty = true;
    return formatter.formatValue(value);
}