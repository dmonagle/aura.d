module aura.services.mandrill;

public import aura.services.mandrill.client;
public import aura.services.mandrill.structs;
public import aura.services.mandrill.api;

unittest {
	import std.stdio;
	import aura.data.json;

	auto mandrillTest = new Client("XjgkAguNxII6sVtU4AygVQ"); // TEST API KEY
	//auto mandrill = new Client("CrfvrZ_JxJVataerlvE65g"); // PRODUCTION API KEY
	/*

	mandrill.request("users/info", Json.emptyObject, (scope req) {}, (scope res) {
			auto jsonPayload = res.readJson;
			writeln(jsonPayload.toPrettyString);
		});
*/

	Message m;
	m.from_email = "support@projectflow.io";
	m.from_name = "Project Flow Support";
	m.to ~= Recipient("david@monagle.com.au", "David Monagle");
	m.subject = "Test Mandrill";
	m.html = "<h1>This is a cool email</h1>";
	m.text = "This is a cool email";

	auto results = mandrillTest.sendTemplate("welcome", m);
	
}

