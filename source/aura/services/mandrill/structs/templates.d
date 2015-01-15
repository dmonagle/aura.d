module aura.services.mandrill.structs.templates;

/// the injection of a single piece of content into a single editable region
struct TemplateContent {
	/// the name of the mc:edit editable region to inject into
	string name;
	/// the content to inject
	string content;
}