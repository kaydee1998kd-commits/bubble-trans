# BubbleTrans Jailbreak Tweak

BubbleTrans is the real floating-bubble version for jailbroken devices.

It injects only into Xianyu:

```text
com.taobao.fleamarket
com.taobao.idlefish
```

When Xianyu opens, a draggable `EN` bubble appears. Tap it to capture the visible Xianyu screen, run Apple Vision OCR locally, translate detected Chinese text to English, and place English labels directly over the Chinese text positions.

## Install

Use the `.deb` package from the GitHub Actions artifact or the `release/` folder:

- `BubbleTrans-rootless.deb` for rootless jailbreaks such as modern palera1n rootless setups.
- `BubbleTrans-rootful.deb` for older/rootful jailbreak setups.

Direct repository paths:

```text
release/BubbleTrans-rootless-0.2.0.deb
release/BubbleTrans-rootful-0.2.0.deb
release/BubbleTrans-rootless-0.1.1.deb
release/BubbleTrans-rootful-0.1.1.deb
release/BubbleTrans-rootless.deb
release/BubbleTrans-rootful.deb
```

Install with Sileo, Zebra, Filza, or:

```sh
dpkg -i BubbleTrans-rootless.deb
killall SpringBoard
```

## Notes

- The tweak sends recognized text to MyMemory for translation.
- Version `0.2.2` uses accurate Chinese OCR, tries Google's public translation endpoint first, batches translations for speed, then falls back to MyMemory.
- Inline labels are intentionally compact and truncated so Xianyu remains readable behind them.
- It overlays OCR lines, not true private Xianyu text nodes, so scrolling the page after translation requires tapping `EN` again.
- If Xianyu changes its bundle identifier, update `tweak/BubbleTrans.plist`.
- This is independent from the TrollStore IPA. TrollStore installs apps; this tweak must be installed by the jailbreak package manager.
