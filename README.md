# XiBubble

XiBubble is an iOS 15 screenshot translator aimed at Xianyu browsing on older iPhones.

It does not try to draw a permanent Android-style overlay on top of Xianyu. A standalone TrollStore IPA cannot reliably keep a global floating bubble above another app without jailbreak tweak injection. Instead, XiBubble gives you the closest practical IPA workflow:

1. Take a screenshot in Xianyu.
2. Tap the screenshot thumbnail.
3. Tap Share.
4. Choose XiBubble.
5. Read and copy the translated text.

The main app also lets you pick a saved screenshot or paste an image from the clipboard.

For jailbroken devices, this repo also includes **BubbleTrans**, a real floating-bubble tweak for Xianyu. See `JAILBREAK_TWEAK.md`.

## Features

- iOS 15.0+ deployment target for iPhone 6s on iOS 15.8.5.
- Chinese OCR using Apple's Vision framework.
- English translation by default.
- MyMemory translation provider works without an API key.
- Optional LibreTranslate-compatible endpoint and API key.
- Share Extension for screenshot share-sheet use.

## Important Notes

- OCR and translation send recognized text to the selected translation provider.
- The default provider is public and may rate-limit or fail sometimes.
- For better privacy and reliability, use your own LibreTranslate server or another compatible endpoint.
- A true always-on floating translation bubble over Xianyu requires a jailbreak tweak, not just a TrollStore IPA.

## Build

This repository includes a macOS build script:

```sh
./build_ipa_macos.sh
```

The script requires Xcode. If `ldid` is installed, it will fake-sign the app binaries for TrollStore packaging.

The IPA will be written to:

```text
dist/XiBubble.ipa
```

If you do not have a Mac, push this folder to a GitHub repository and run the included **Build XiBubble IPA** workflow from the Actions tab. The finished IPA is uploaded as a workflow artifact.

This repository also keeps the latest generated IPA at:

```text
release/XiBubble.ipa
```

The jailbreak tweak packages are kept at:

```text
release/BubbleTrans-rootless-0.1.1.deb
release/BubbleTrans-rootful-0.1.1.deb
release/BubbleTrans-rootless.deb
release/BubbleTrans-rootful.deb
```
