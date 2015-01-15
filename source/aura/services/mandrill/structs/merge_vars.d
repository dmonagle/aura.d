module aura.services.mandrill.structs.merge_vars;

import vibe.data.json;

struct RecipientMergeVar {
	/// the email address of the recipient that the merge variables should apply to (required)
	string rcpt;
	/// the recipient's merge variables
	MergeVar[] vars;
}

struct MergeVar {
	/// the merge variable's name. Merge variable names are case-insensitive and may not start with _
	string name;
	/// the merge variable's content
	Json content = Json(null);
}

