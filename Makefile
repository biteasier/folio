.PHONY: all build run install uninstall test snapshot icon release clean

APP  := build/Folio.app
DEST := /Applications/Folio.app

all: build

## Build build/Folio.app (arm64, release)
build:
	@./Scripts/build.sh

## Build, then open the showcase document in it
run: build
	@open -a $(APP) Samples/Showcase.md

## Copy into /Applications
install: build
	@pkill -x Folio 2>/dev/null || true
	@rm -rf $(DEST)
	@cp -R $(APP) $(DEST)
	@echo "Installed to $(DEST)"

uninstall:
	@pkill -x Folio 2>/dev/null || true
	@rm -rf $(DEST)
	@echo "Removed $(DEST)"

## Parser unit tests
test:
	@swift test

## Render Samples/Showcase.md to build/showcase.png and build/showcase-dark.png
snapshot: build
	@open -n -W --stdout /dev/stdout $(APP) --args --snapshot $(PWD)/Samples/Showcase.md $(PWD)/build/showcase.png
	@open -n -W --stdout /dev/stdout $(APP) --args --snapshot $(PWD)/Samples/Showcase.md $(PWD)/build/showcase-dark.png --dark

## Redraw the icon
icon:
	@swift Scripts/make-icon.swift Resources && iconutil -c icns Resources/Folio.iconset -o Resources/Folio.icns && rm -rf Resources/Folio.iconset

## Zip the app for a GitHub release: dist/Folio-<version>-arm64.zip (+ .sha256)
release: test build
	@./Scripts/package.sh

clean:
	@rm -rf build .build dist
