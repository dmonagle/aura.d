module aura.services.mandrill.structs.Attachment;

/// a single supported attachment
struct Attachment {
	/// the MIME type of the attachment
	string type;
	/// the file name of the attachment
	string name;
	/// the content of the attachment as a base64-encoded string
	string content;
}

