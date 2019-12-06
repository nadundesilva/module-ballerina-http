// Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/lang.'int as ints;
import ballerina/stringutils;
import ballerina/time;

# Represents a Cookie.
# 
# + name - Name of the cookie
# + value - Value of the cookie
# + path - URI path to which the cookie belongs
# + domain - Host to which the cookie will be sent
# + maxAge - Maximum lifetime of the cookie represented as the number of seconds until the cookie expires
# + expires - Maximum lifetime of the cookie represented as the date and time at which the cookie expires
# + httpOnly - Cookie is sent only to HTTP requests
# + secure - Cookie is sent only to secure channels
# + creationTime - Creation time of the cookie
# + lastAccessedTime - Last-accessed time of the cookie
# + hostOnly - Cookie is sent only to the requested host
public type Cookie object {

    public string name = "";
    public string value = "";
    public string domain = "";
    public string path = "";
    public int maxAge = 0;
    public string expires = "";
    public boolean httpOnly = false;
    public boolean secure = false;
    public time:Time creationTime = time:currentTime();
    public time:Time lastAccessedTime = time:currentTime();
    public boolean hostOnly = false;

    // Returns false if the cookie will be discarded at the end of the "session"; true otherwise.
    public function isPersistent() returns boolean {
        if (self.expires == "" && self.maxAge == 0) {
            return false;
        }
        return true;
    }

    // Returns true if the attributes of the cookie are in the correct format; false otherwise.
    public function isValid() returns boolean | error {
        error invalidCookieError;
        if (self.name == "" || self.value == "") {
            invalidCookieError = error("Empty name value pair");
            return invalidCookieError;
        }
        if (self.domain != "") {
            self.domain = self.domain.toLowerAscii();
        }
        if (self.domain.startsWith(".")) {
            self.domain = self.domain.substring(1, self.domain.length());
        }
        if (self.domain.endsWith(".")) {
            self.domain = self.domain.substring(0, self.domain.length() - 1);
        }
        if (self.path != "" && (!self.path.startsWith("/") || stringutils:contains(self.path, "?"))) {
            invalidCookieError = error("Path is not in correct format ");
            return invalidCookieError;
        }
        if (self.expires != "" && !toGmtFormat(self)) {
            invalidCookieError = error("Time is not in correct format");
            return invalidCookieError;
        }
        if (self.maxAge < 0) {
            invalidCookieError = error("Max Age is less than zero");
            return invalidCookieError;
        }
        return true;
    }

    // Gets the Cookie object in its string representation to be used in the ‘Set-Cookie’ header of the response.
    function toStringValue() returns string {
        string setCookieHeaderValue = "";
        setCookieHeaderValue = appendNameValuePair(setCookieHeaderValue, self.name, self.value);
        if (self.domain != "") {
            setCookieHeaderValue = appendNameValuePair(setCookieHeaderValue, DOMAIN_ATTRIBUTE, self.domain);
        }
        if (self.path != "") {
            setCookieHeaderValue = appendNameValuePair(setCookieHeaderValue, PATH_ATTRIBUTE, self.path);
        }
        if (self.expires != "") {
            setCookieHeaderValue = appendNameValuePair(setCookieHeaderValue, EXPIRES_ATTRIBUTE, self.expires);
        }
        if (self.maxAge > 0) {
            setCookieHeaderValue = appendNameIntValuePair(setCookieHeaderValue, MAX_AGE_ATTRIBUTE, self.maxAge);
        }
        if (self.httpOnly) {
            setCookieHeaderValue = appendOnlyName(setCookieHeaderValue, HTTP_ONLY_ATTRIBUTE);
        }
        if (self.secure) {
            setCookieHeaderValue = appendOnlyName(setCookieHeaderValue, SECURE_ATTRIBUTE);
        }
        setCookieHeaderValue = setCookieHeaderValue.substring(0, setCookieHeaderValue.length() - 2);
        return setCookieHeaderValue;
    }
};

// Converts the cookie's expiry time into the GMT format.
function toGmtFormat(Cookie cookie) returns boolean {
    time:Time | error t1 = time:parse(cookie.expires, "yyyy-MM-dd HH:mm:ss");
    if (t1 is time:Time) {
        string | error timeString = time:format(<time:Time>t1, "E, dd MMM yyyy HH:mm:ss ");
        if (timeString is string) {
            cookie.expires = timeString + "GMT";
            return true;
        }
        return false;
    }
    return false;
}

const string DOMAIN_ATTRIBUTE = "Domain";
const string PATH_ATTRIBUTE = "Path";
const string EXPIRES_ATTRIBUTE = "Expires";
const string MAX_AGE_ATTRIBUTE = "Max-Age";
const string HTTP_ONLY_ATTRIBUTE = "HttpOnly";
const string SECURE_ATTRIBUTE = "Secure";
const EQUALS = "=";
const SPACE = " ";
const SEMICOLON = ";";

function appendNameValuePair(string setCookieHeaderValue, string name, string value) returns string {
    return setCookieHeaderValue + name + EQUALS + value + SEMICOLON + SPACE;
}

function appendOnlyName(string setCookieHeaderValue, string name) returns string {
    return setCookieHeaderValue + name + SEMICOLON + SPACE;
}

function appendNameIntValuePair(string setCookieHeaderValue, string name, int value) returns string {
    return setCookieHeaderValue + name + EQUALS + value.toString() + SEMICOLON + SPACE;
}

// Returns the cookie object from the string value of the "Set-Cookie" header.
function parseSetCookieHeader(string cookieStringValue) returns Cookie {
    Cookie cookie = new;
    string cookieValue = cookieStringValue;
    string[] result = stringutils:split(cookieValue, SEMICOLON + SPACE);
    string[] nameValuePair = stringutils:split(result[0], EQUALS);
    cookie.name = nameValuePair[0];
    cookie.value = nameValuePair[1];
    foreach var item in result {
        nameValuePair = stringutils:split(item, EQUALS);
        match nameValuePair[0] {
            DOMAIN_ATTRIBUTE => {
                cookie.domain = nameValuePair[1];
            }
            PATH_ATTRIBUTE => {
                cookie.path = nameValuePair[1];
            }
            MAX_AGE_ATTRIBUTE => {
                int | error age = ints:fromString(nameValuePair[1]);
                if (age is int) {
                    cookie.maxAge = age;
                }
            }
            EXPIRES_ATTRIBUTE => {
                cookie.expires = nameValuePair[1];
            }
            SECURE_ATTRIBUTE => {
                cookie.secure = true;
            }
            HTTP_ONLY_ATTRIBUTE => {
                cookie.httpOnly = true;
            }
        }
    }
    return cookie;
}

// Returns an array of cookie objects from the string value of the "Cookie" header.
function parseCookieHeader(string cookieStringValue) returns Cookie[] {
    Cookie[] cookiesInRequest = [];
    string cookieValue = cookieStringValue;
    string[] nameValuePairs = stringutils:split(cookieValue, SEMICOLON + SPACE);
    foreach var item in nameValuePairs {
        string[] nameValue = stringutils:split(item, EQUALS);
        Cookie cookie = new;
        cookie.name = nameValue[0];
        cookie.value = nameValue[1];
        cookiesInRequest.push(cookie);
    }
    return cookiesInRequest;
}

// Returns a value to be used for sorting an array of cookies in order to create the "Cookie" header in the request.
// This value is returned according to the rules in [RFC-6265](https://tools.ietf.org/html/rfc6265#section-5.4).
function comparator(Cookie c1, Cookie c2) returns int {
    if (c1.path.length() > c2.path.length()) {
        return -1;
    }
    if (c1.path.length() < c2.path.length()) {
        return 1;
    }
    if (c1.creationTime.time > c2.creationTime.time) {
        return 1;
    }
    if (c1.creationTime.time < c2.creationTime.time) {
        return -1;
    }
    return 0;
}
