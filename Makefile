.PHONY: build run test clean app install update

# Build the executable (debug).
build:
	swift build

# Build release, assemble .app bundle, and install to /Applications.
app:
	bash Scripts/build-app.sh

# Alias: rebuild + reinstall + relaunch. Run after pulling changes.
update: app
	open /Applications/YipYip.app

# Run the debug build directly (menu bar won't appear without an app bundle).
run: build
	.build/debug/YipYip

# Run all unit tests.
test:
	swift test

# Remove build artifacts.
clean:
	swift package clean
	rm -rf .build/YipYip.app
