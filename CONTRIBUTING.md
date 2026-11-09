# Contributing to CommissieWijzer

CommissieWijzer is a macOS and iPadOS PDF reading and preparation app. Contributions to this source
tree are welcome under the MIT license. By submitting a contribution, you
agree that it may be distributed under that license.

## Build

Requirements: macOS 14 or later for the Swift package and Mac app. iPad builds
also require Xcode and the iPadOS SDK; see `README.md` for platform-specific
build modes and signing requirements.

Build the Swift package locally:

```sh
swift build -c release
```

The repository's `build-app.sh` creates the Mac app bundle and icon using
Apple's `sips`, `iconutil`, and `codesign` tools. `build-ipad.sh` builds the
iPad app from the generated Xcode project. Preview and simulator/device builds
are available locally; iCloud-enabled and Store builds require matching
publisher signing assets. See `README.md` for the exact commands.

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
