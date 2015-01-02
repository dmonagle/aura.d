module aura.security.roles;

import vibe.data.serialization;

mixin template Roles(RoleEnum) {
	import std.algorithm;

	@optional {
		@byName RoleEnum[] roles;
	}

	/// Check if a user has any of the supplied roles
	bool hasRole(RoleEnum[] checkRoles ...) {
		foreach(role; checkRoles) if (roles.canFind(role)) return true;
		return false;
	}
	
	/// Add a role to the user
	void addRole(RoleEnum r) {
		if (!roles.canFind(r)) roles ~= r;
	}

	void addRoles(RoleEnum[] roles ...) {
		foreach(role; roles) addRole(role);
	}

	/// Remove a role from a user
	void removeRole(RoleEnum r) {
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

		mixin Roles!Role;
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