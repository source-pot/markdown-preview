#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
BINARY_NAME="mdview"

echo "Building mdview..."
swift build -c release

echo "Installing to $INSTALL_DIR..."
sudo cp ".build/release/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"

echo "Done! You can now run: mdview <file.md>"
