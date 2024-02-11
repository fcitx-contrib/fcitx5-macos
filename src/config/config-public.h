#pragma once
#include <string>

/// Get a json document describing the current config for uri.
///
/// The formats of the json object are:
///  - {"ERROR": "error message"}, if there are errors
///  - otherwise, it is a json object satisfying
///    returnValue["Children"][i]["Children"][j] corresponds to an option object
///    Foo/Bar, satisfying returnValue["Children"][i]["Option"] == "Foo" and
///    returnValue["Children"][i]["Children"][j]["Option"] == "Bar"
///
/// type OptionObject = {
///   Option: str,
///   Type: str,
///   Description: str,
///   DefaultValue: T,
///   Value: T,                // Current value
///   ... other keys,          // Relevant to the option type
///   Children: [
///     ... suboptions
///   ]
/// }
std::string getConfig(const char *uri);

/// This function applies jsonPatch to the current "Value" for config
/// uri.
///
/// This function updates the current value and then reload the config.
bool setConfig(const char *uri, const char *jsonPatch);
