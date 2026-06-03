# Building the TrollStore IPA

This project needs macOS with Xcode because iOS device binaries require Apple's iPhoneOS SDK.

## Quick Build

```sh
cd XiBubble
./build_ipa_macos.sh
```

If you cloned or copied this folder onto a Mac, make the script executable first:

```sh
chmod +x build_ipa_macos.sh
./build_ipa_macos.sh
```

## Optional ldid

TrollStore IPAs are commonly fake-signed. If you have Homebrew, install `ldid`:

```sh
brew install ldid
```

The script still packages the IPA if `ldid` is missing, but TrollStore installs are usually smoother when the binaries are fake-signed.

## Install

1. Copy `dist/XiBubble.ipa` to the iPhone.
2. Open it with TrollStore.
3. Install.

For iPhone 6s on iOS 15.8.5, iOS Guide currently lists the device family in the TrollStore-supported range.

## No Mac

This folder includes `.github/workflows/build-ipa.yml`. Push the project to GitHub, open Actions, run **Build XiBubble IPA**, then download the `XiBubble-ipa` artifact.
