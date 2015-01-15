module aura.services.mandrill.structs.Image;

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
