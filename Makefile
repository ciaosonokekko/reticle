.PHONY: dmg clean

# Build the Release app and package dist/Reticle.dmg
dmg:
	bash scripts/build-dmg.sh

# Remove build artifacts
clean:
	rm -rf build dist
