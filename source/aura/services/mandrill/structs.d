module aura.services.mandrill.structs;

import aura.data.json; 
import std.typecons;

/// a single supported attachment
struct Attachment {
	/// the MIME type of the attachment
	string type;
	/// the file name of the attachment
	string name;
	/// the content of the attachment as a base64-encoded string
	string content;
}

/// a single embedded image
struct Image {
	/// the MIME type of the image - must start with "image/"
	string type;
	/// the Content ID of the image - 
	/// use <img src="cid:THIS_VALUE"> to reference the image in your HTML content
	string name;
	/// the content of the image as a base64-encoded string
	string content;
}

struct Message {
	/// the full HTML content to be sent
	string html; 
	/// optional full text content to be sent
	string text; 
	/// the message subject
	string subject;
	/// the sender email address.
	string from_email;
	/// optional from name to be used
	string from_name;
	/// an array of recipient information
	Recipient[] to;
	/// optional extra headers to add to the message (most headers are allowed)
	string[string] headers;
	/// whether or not this message is important, and should be delivered ahead of non-important messages
	bool important;
	/// whether or not to turn on open tracking for the message
	Nullable!bool track_opens;
	/// whether or not to turn on click tracking for the message
	Nullable!bool track_clicks;
	/// whether or not to automatically generate a text part for messages that are not given text
	Nullable!bool auto_text;
	/// whether or not to automatically generate an HTML part for messages that are not given HTML
	Nullable!bool auto_html;
	/// whether or not to automatically inline all CSS styles provided in the message HTML - only for HTML documents less than 256KB in size
	Nullable!bool inline_css;
	/// whether or not to strip the query string from URLs when aggregating tracked URL data
	Nullable!bool url_strip_qs;
	/// whether or not to expose all recipients in to "To" header for each email
	Nullable!bool preserve_recipients;
	/// set to false to remove content logging for sensitive emails
	Nullable!bool view_content_link;
	/// an optional address to receive an exact copy of each recipient's email
	Nullable!string bcc_address;
	/// a custom domain to use for tracking opens and clicks instead of mandrillapp.com
	Nullable!string tracking_domain;
	/// a custom domain to use for SPF/DKIM signing instead of mandrill (for "via" or "on behalf of" in email clients)
	Nullable!string signing_domain;
	/// a custom domain to use for the messages's return-path
	Nullable!string return_path_domain;
	/// whether to evaluate merge tags in the message. Will automatically be set to true if either merge_vars or global_merge_vars are provided.
	bool merge;
	/// the merge tag language to use when evaluating merge tags, either mailchimp or handlebars
	/// oneof(mailchimp, handlebars)
	@byName MergeLanguage merge_language;
	/// global merge variables to use for all recipients. You can override these per recipient.
	MergeVar[] global_merge_vars;
	/// per-recipient merge variables, which override global merge variables with the same name.
	RecipientMergeVar[] merge_vars;
	/// an array of string to tag the message with. 
	/// Stats are accumulated using tags, though we only store the first 100 we see, so this should not be unique or change frequently. 
	/// Tags should be 50 characters or less. Any tags starting with an underscore are reserved for internal use and will cause errors.
	string[] tags;
	/// the unique id of a subaccount for this message - must already exist or will fail with an error
	Nullable!string subaccount;
	/// an array of strings indicating for which any matching URLs will automatically have Google Analytics parameters appended to their query string automatically.
	string[] google_analytics_domains;
	/// optional string indicating the value to set for the utm_campaign tracking parameter. If this isn't provided the email's from address will be used instead.
	string[] google_analytics_campaign;
	/// metadata an associative array of user metadata. 
	/// Mandrill will store this metadata and make it available for retrieval. 
	/// In addition, you can select up to 10 metadata fields to index and make searchable using the Mandrill search api.
	string[] metadata;
	/// Per-recipient metadata that will override the global values specified in the metadata parameter.
	RecipientMetadata[] recipient_metadata;
	/// an array of supported attachments to add to the message
	Attachment[] attachments;
	/// an array of embedded images to add to the message
	Image[] images;
	/// enable a background sending mode that is optimized for bulk sending. 
	/// In async mode, messages/send will immediately return a status of "queued" for every recipient. 
	/// To handle rejections when sending in async mode, set up a webhook for the 'reject' event. 
	/// Defaults to false for messages with no more than 10 recipients; messages with more than 10 recipients are always sent asynchronously, 
	/// regardless of the value of async.
	bool async;
	/// the name of the dedicated ip pool that should be used to send the message. 
	/// If you do not have any dedicated IPs, this parameter has no effect. 
	/// If you specify a pool that does not exist, your default pool will be used instead.
	string ip_pool;
	/// when this message should be sent as a UTC timestamp in YYYY-MM-DD HH:MM:SS format. 
	/// If you specify a time in the past, the message will be sent immediately. 
	/// An additional fee applies for scheduled email, and this feature is only available to accounts with a positive balance.
	string send_at;
}

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

enum MergeLanguage {
	mailchimp,
	handlebars
}

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

/// the sending results for a single recipient
struct SendResult {
	/// the sending status of the recipient - either "sent", "queued", "scheduled", "rejected", or "invalid"
	string status;
	/// the email address of the recipient
	string email;
	/// the reason for the rejection if the recipient status is "rejected"
	/// one of "hard-bounce", "soft-bounce", "spam", "unsub", "custom", "invalid-sender", "invalid", "test-mode-limit", or "rule"
	@optional Nullable!string reject_reason;
	
	/// the message's unique id
	string _id;
}

/// the injection of a single piece of content into a single editable region
struct TemplateContent {
	/// the name of the mc:edit editable region to inject into
	string name;
	/// the content to inject
	string content;
}

struct User {
}
