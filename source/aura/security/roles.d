﻿module aura.security.roles;

import vibe.data.serialization;

/// Mixin that allows the class to have a "roles" member which can contain one or more roles
mixin template MultiRoles(RoleEnum) {
	import std.algorithm;

	@optional {
		@byName RoleEnum[] roles;
	}

	/// Check if a user has any of the supplied roles
	bool hasRole(const RoleEnum[] checkRoles ...) const {
		foreach(role; checkRoles) if (roles.canFind(role)) return true;
		return false;
	}
	
	/// Add a role to the user
	void addRole(const RoleEnum r) {
		if (!roles.canFind(r)) roles ~= r;
	}

	void addRoles(const RoleEnum[] roles ...) {
		foreach(role; roles) addRole(role);
	}

	/// Remove a role from a user
	void removeRole(const RoleEnum r) {
		roles = roles.remove!((role) => role == r);
	}
}

unittest {
	struct User {
		enum Role {
			admin,
			member,
			guest
		}

		mixin MultiRoles!Role;
	}

	User u;

	assert(u.roles.length == 0);
	u.addRole(User.Role.admin);
	assert(u.roles.length == 1);

	// Adding the role again should leave the length the same
	u.addRole(User.Role.admin);
	assert(u.roles.length == 1);

	assert(u.hasRole(User.Role.admin));
	assert(!u.hasRole(User.Role.member));

	u.addRole(User.Role.member);
	assert(u.roles.length == 2);
	assert(u.hasRole(User.Role.admin));
	assert(u.hasRole(User.Role.member));
	assert(!u.hasRole(User.Role.guest));

	u.removeRole(User.Role.admin);
	assert(u.roles.length == 1);
	assert(!u.hasRole(User.Role.admin));
	assert(u.hasRole(User.Role.member));
	assert(!u.hasRole(User.Role.guest));
}