module aura.util.external_command;

import core.time : msecs;

import std.process;
import std.string;
import std.path;

import std.stdio;
import vibe.d;
import vibe.stream.stdio;

string externalCommand(string[] command, string input = "", string workDir = "")
in {
	assert(command.length > 0);
} 
body {
	struct PipeCommand {
		string[] command;
		string input;
		string workDir;
	}

	shared auto pipeCommand = cast(shared)PipeCommand(command, input, workDir);

	// Run the whole externalCommand inside a worker thread
	auto task = runWorkerTaskH((shared PipeCommand pipeCommand, Task parent) {
		auto pc = cast(PipeCommand)pipeCommand;

		// This will spawn a process in a separate thread. This uses the std library
		auto pipes = pipeProcess(
			pc.command,
			cast(Redirect)7,
			cast(const(string[string]))null,
			cast(Config)0,
			pc.workDir.length ? pc.workDir : cast(string)null
		);

		// Write the input into the processes stdin
		if (pc.input.length) pipes.stdin.writeln(pc.input);
		pipes.stdin.close();
		
		bool complete;
		string output;

		// This will block
		while (!pipes.stdout.eof) {
			ubyte[2048] buffer;
			auto data = pipes.stdout.rawRead(buffer);
			if (data.length) {
				output ~= cast(string)data;
			}
			vibe.core.core.yield; // Give other threads a chance to do things??
		}

		// Sends the result back to our main task
		parent.sendCompat(output);
	}, cast(shared PipeCommand)pipeCommand, Task.getThis);

	// Wait for the worker thread to send the response.
	auto response = receiveOnlyCompat!string();
	return response;
}

/// It's a good idea to wrap this in a try/catch for a JSONException 
Json externalJsonCommand(string[] command, string input, string workDir = "") {
	auto stringResult = externalCommand(command, input, workDir);
    return stringResult.parseJsonString();
}

// XLSX to CSV. Returns CSV.
string xlsxReadToCSV(string filePath) {
	return externalCommand(["xlsx2csv.py", "-f", "%Y-%m-%d", filePath]);
}

// CSV to XLSX. Writes to new file.
string csvReadtoXLSX(string fromFilePath, string toFilePath) {
	return externalCommand(["ssconvert", fromFilePath, toFilePath]);
}

unittest {
	/*
	import std.stdio;
	import colorize;

	writeln("Testing xlsxReadToCSV".color(fg.light_green));
	writeln("private/imports/retSwhOver700L/swh-models-more-700l-v23.xlsx".xlsxReadToCSV.color(fg.light_blue));
	*/
}