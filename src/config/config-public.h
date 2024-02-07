#pragma once

/// Get a json document describing the current config for uri.
///
/// The formats of the json object are:
///  - {"ERROR": "error message"}, if there are errors
///  - otherwise, it is a json object satisfying
///    returnValue["Foo"]["Bar"] corresponds to an option object Foo/Bar.
///
/// type OptionObject = {
///   Type: str,
///   Description: str,
///   DefaultValue: T,
///   Value: T,                // Current value
///   ... other keys,          // Relevant to the option type
///   ... suboptions
/// }
std::string getConfig(const char *uri);

/// This function applies jsonPatch to the current "Value" for config
/// uri.
///
/// This function updates the current value and then reload the config.
bool setConfig(const char *uri, const char *jsonPatch);
