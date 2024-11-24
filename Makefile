.PHONY: all
all: gpgedit

.PHONY: clean
clean:
	-rm gpgedit

gpgedit: main.go
	CGO_ENABLED=0 go build -trimpath
