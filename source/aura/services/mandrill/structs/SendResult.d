module aura.services.mandrill.structs.SendResult;

import std.typecons;

/// the sending results for a single recipient
struct SendResult {
	/// the email address of the recipient
	/// the sending status of the recipient - either "sent", "queued", "scheduled", "rejected", or "invalid"
	string email;

	/// the reason for the rejection if the recipient status is "rejected"
	/// one of "hard-bounce", "soft-bounce", "spam", "unsub", "custom", "invalid-sender", "invalid", "test-mode-limit", or "rule"
	Nullable!string reject_reason;

	/// the message's unique id
	string _id;
}

