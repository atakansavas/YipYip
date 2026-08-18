
---

**About the attached `YipYip.zip`:** it is ad-hoc signed by CI and not notarized,
so macOS quarantines it on download. Building from source is the recommended
path:

```bash
git clone https://github.com/atakansavas/YipYip.git && cd YipYip && ./Scripts/build-app.sh
```

If you would rather use the zip, clear the quarantine flag after unzipping:

```bash
xattr -dr com.apple.quarantine /Applications/YipYip.app
```
