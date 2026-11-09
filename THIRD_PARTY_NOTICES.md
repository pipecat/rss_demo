# Third-party notices

The demo is built using the following pinned dependencies. Full license files are included in the app's `Contents/Resources/Licenses` directory.

- FeedKit 10.10.2 — MIT, copyright Nuno Dias and contributors. https://github.com/nmdias/FeedKit
- SwiftSoup 2.14.3 — MIT, copyright Nabil Chatbi and contributors. https://github.com/scinfu/SwiftSoup
- Mozilla Readability 0.6.0, `Readability.js` — Apache-2.0, copyright Arc90 Inc., Mozilla and contributors. Original source: https://github.com/mozilla/readability/tree/0.6.0
- Mozilla `JSDOMParser.js` from the same tag — **MPL-2.0**, as specified in its file header (different from Readability's repository-wide Apache license). This file is distributed unmodified, in source form, in this repository and in the application resources. License: https://www.mozilla.org/MPL/2.0/

Readability and JSDOMParser execute in JavaScriptCore with no native bridge, network, filesystem or browser capabilities. Source-page scripts are never evaluated. HTML is normalized to XML-compatible markup before JSDOMParser, and extracted content is sanitized separately.

NetNewsWire (https://github.com/Ranchero-Software/NetNewsWire, MIT) is an architectural and interaction reference only. No NetNewsWire code, brand assets or themes are copied into this demo.

The project's own open-source license has not yet been selected. This local demo is not a public release. Live third-party feed/article caches belong in the user's Application Support directory and are not distributed in the source repository or app bundle.
