/**
	* AWS S3
	*
	* Copyright: © 2016 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module aura.aws.s3;

import std.digest.hmac;
import std.digest.sha;
import std.base64;
import std.uri;
import std.datetime;
import std.format;
import std.string;
import std.conv;

/// Generates an AWS S3 Signed URL
string AWS_S3_URI(string region, string accessKeyId, string secretKey, string method, string bucket, string fileName, uint expiryMinutes = 10) 
in {
    assert(bucket.length, "Bucket name must be specified");
}
body {
	auto endPoint = region.length ? format("s3-%s.amazonaws.com", region) : "s3.amazonaws.com";
	auto expiry = Clock.currTime.toUnixTime + (expiryMinutes * 60);
	auto signatureText = format("%s\n\n\n%s\n/%s/%s", method, expiry, bucket, fileName).representation;
	auto signature = Base64.encode(signatureText.hmac!SHA1(secretKey.representation));

	auto query = format("AWSAccessKeyId=%s&Expires=%s&Signature=%s", accessKeyId.encodeComponent, expiry, signature.encodeComponent);
	return format("https://%s/%s/%s?%s", endPoint, bucket, fileName, query);	
}