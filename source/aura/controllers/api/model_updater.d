module aura.controllers.api.model_updater;

import std.regex;

import aura.data.bson;
import aura.data.json;
import aura.graph.core;

import vibe.web.web;
import vibe.http.router;
import vibe.core.log;

class ModelUpdater(S) {
	this() {
		_serializer = new S();
	}

	@property auto model() {
		return _serializer.data;
	}
	
	@property void model(S.DataType model) {
		_serializer.data = model;
		_originalJson = model.serializeToJson;
	}
	
	@property auto context() {
		return _serializer.context;
	}
	
	@property void context(C)(C context) {
		_serializer.context = context;
	}

	@property Json updates() {
		return _updates;
	}

	@property void updates(Json jsonUpdates) { _updates = jsonUpdates; }
	@property void updates(string stringUpdates) { _updates = stringUpdates.parseJsonString; }

	/// Builds a replacement of the original model with the merged changes and
	/// if the original was in a graph, reinjects the merged version
	S.DataType mergedModel() {
		S.DataType model;

		auto merge = jsonDup(_originalJson);
		merge.jsonMerge(filteredUpdates);
		model.deserializeJson(merge);

		static if (is(model : GraphModelInterface)) {
			model.graphState = _serializer.data.graphState;
			if (model.graphInstance) {
				model.graphInstance.inject(model);
			}
		}

		return model;
	}

private:
	Json _originalJson;
	Json _updates;
	S _serializer;

	Json filteredUpdates() {
		if (!isObject(_updates)) return Json.emptyObject;
		return _serializer.jsonFilterUpdate(_serializer.jsonFilterAccess(_updates));
	}
}

version (unittest) {
	import aura.data.json.context_serializer;
	import aura.graph.core;

	struct TestJob {
		string title;
		@optional int level;
	}

	class TestUser {
		@optional BsonObjectID _id;
		string firstName;
		@optional string surname;
		@optional string title;
		int salary;
		@optional TestJob job;

		@ignore GraphState graphState;
	}

	class TestUserSerializer : ContextSerializer!(TestUser, TestUser) {
		override void filter() {
			accessFilter.add("salary");
			updateFilter.add("job.level");
		}
	}
}

unittest {
	auto user = new TestUser;
	user.firstName = "John";
	user.surname = "Smith";
	user.job.title = "Timelord";
	user.job.level = 10;
	user.salary = 100000;
	user.graphState.persisted = true;

	auto updater = new ModelUpdater!TestUserSerializer;
	updater.model = user;
	updater.context = user;

	updater.updates = `{"firstName": "Rose", "job": {"title": "Shop Assistant", "level": 5 }, "salary": 50000 }`;
	auto updatedUser = updater.mergedModel;

	assert(updatedUser.job.title == "Shop Assistant");
	assert(updatedUser.surname == "Smith");
	assert(updatedUser.salary == 100000);
	assert(updatedUser.job.level == 10);
}
