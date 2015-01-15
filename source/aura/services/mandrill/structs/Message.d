module aura.services.mandrill.structs.Message;

import aura.services.mandrill.structs.Attachment;
import aura.services.mandrill.structs.Image;
import aura.services.mandrill.structs.recipients;
import aura.services.mandrill.structs.merge_vars;

import vibe.data.serialization; 

import std.typecons;

enum MergeLanguage {
	mailchimp,
	handlebars
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
