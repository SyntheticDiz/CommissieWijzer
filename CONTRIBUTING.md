# Contributing to CommissieWijzer

CommissieWijzer is a macOS PDF reading and preparation app. Contributions to this source
tree are welcome under the MIT license. By submitting a contribution, you
agree that it may be distributed under that license.

## Build

Requirements: macOS 14 or later and a Swift toolchain compatible with
`Package.swift`.

Build the Swift package locally:

```sh
swift build -c release
```

The repository's `build-app.sh` additionally creates an app bundle and app
icon from `Assets/CommissieWijzer.png` using Apple's `sips`, `iconutil`, and `codesign`
tools. Preview mode is locally signed. Store mode requires the publisher’s external certificates and a matching provisioning profile.

## Changes

- Keep changes focused and explain user-visible behavior in the pull request.
- Do not add real documents, personal data, credentials, local machine paths,
  or generated app/build artifacts.
- Tests and fixtures must use synthetic data. Do not submit excerpts from
  municipal or other real-world documents.
- Preserve notices for vendored or generated third-party code. Consult
  `ThirdPartyLicenses/` before changing those components.

## Pull requests

Include the relevant build or test command and its result. Do not include API
keys or ask maintainers to run requests against real documents or live services.
