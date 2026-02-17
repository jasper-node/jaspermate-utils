# Build update-baud tool into dist/
update-baud:
	mkdir -p dist
	go build -o dist/update-baud ./cmd/update-baud

.PHONY: update-baud
