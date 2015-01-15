module aura.services.mandrill.structs.recipients;

import vibe.data.serialization;

/// metadata for a single recipient
struct RecipientMetadata {
	/// the email address of the recipient that the metadata is associated with
	string rcpt;
	/// an associated array containing the recipient's unique metadata. 
	/// If a key exists in both the per-recipient metadata and the global metadata, the per-recipient metadata will be used.
	string[] values;
}

enum RecipientType {
	to,
	cc,
	bcc
}

/// a single recipient's information.
struct Recipient {
	/// the email address of the recipient
	string email;
	/// the optional display name to use for the recipient
	string name;
	/// the header type to use for the recipient, defaults to "to" if not provided
	/// oneof(to, cc, bcc)
	@byName RecipientType type;
}

