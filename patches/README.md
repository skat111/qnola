# Patches

Place Telegram iOS patches here as `*.patch` files produced by `git format-patch`.

Example:

```bash
cd telegram-ios-src
git format-patch -1 HEAD --stdout > ../patches/0001-add-qnola-settings.patch
```

The GitHub Actions workflow applies patches in lexical order with `git am`.

