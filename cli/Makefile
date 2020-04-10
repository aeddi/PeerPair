MAKEFILE_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BIN=$(MAKEFILE_DIR)/test
DEPS=$(MAKEFILE_DIR)/main.swift $(MAKEFILE_DIR)/GameService.swift

build: $(BIN)

run: build
	@$(BIN)

$(BIN): $(DEPS)
	@swiftc -o $(BIN) $(DEPS)
