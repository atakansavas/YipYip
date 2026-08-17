# Contributing to YipYip

Thanks for taking the time. YipYip is a small, deliberately dependency-free macOS
app, and the goal is to keep it that way.

## Getting set up

```bash
git clone https://github.com/atakansavas/YipYip.git
cd YipYip
swift test              # should be green before you change anything
./Scripts/build-app.sh  # builds, signs, installs to /Applications
```

You need macOS 14+ and Swift 6. There is nothing else to install — no package
manager, no code generation step.

## Where code goes

- `Sources/YipYipCore/` — logic with **no UI imports**. Anything that can be
  tested without a running app belongs here.
- `Sources/YipYip/` — AppKit and SwiftUI: windows, menus, event taps, glue.

If you find yourself writing an interesting rule inside a view or an
`NSApplicationDelegate`, that is usually a sign it belongs in the core with a
test next to it.

## Tests

Every behavioural change needs a test in `Tests/YipYipCoreTests/`, written with
swift-testing (`@Test`, `#expect`). Things the suite already pins down, as a
guide to the level of detail expected:

- pasteboard classification, including which representation wins when an app
  offers several
- search folding, including that a Turkish locale must not be used for case
  folding
- settings decoding when a file predates a field
- tone envelopes, so a cue never clicks

Run `swift test` before opening a pull request.

## Style

Match the surrounding code. A few conventions that are consistent throughout:

- Comments explain **why**, not what. If a line looks odd but is deliberate, say
  what breaks without it.
- Prefer small, named helpers over long functions with section comments.
- No third-party dependencies. If you need something, check whether a system
  framework already does it.

## Pull requests

- One concern per pull request.
- Describe what you observed, not only what you changed — especially for macOS
  behaviour, where the fix often looks arbitrary without the symptom.
- Note anything you could not verify (permission-dependent paths are hard to
  test in CI, and that is fine — just say so).

## Reporting bugs

Include your macOS version, whether Accessibility is granted (Menu bar →
**Diagnostics…** prints it), and what you copied when things went wrong. The
diagnostics report contains no clipboard contents, so it is safe to paste into an
issue.

For security-sensitive reports, follow [SECURITY.md](SECURITY.md) instead of
opening a public issue.
