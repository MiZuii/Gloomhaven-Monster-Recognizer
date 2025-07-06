#!/bin/bash

# Script to permanently add Flutter to your PATH
# Run this once to add Flutter to your bash profile

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_PATH="$SCRIPT_DIR/flutter/bin"

# Determine which profile file to use
if [ -f "$HOME/.bashrc" ]; then
    PROFILE_FILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    PROFILE_FILE="$HOME/.bash_profile"
else
    PROFILE_FILE="$HOME/.bashrc"
fi

# Check if Flutter path is already in the profile
if grep -q "flutter/bin" "$PROFILE_FILE" 2>/dev/null; then
    echo "Flutter PATH already exists in $PROFILE_FILE"
    echo "Current Flutter PATH entry:"
    grep "flutter/bin" "$PROFILE_FILE"
else
    # Add Flutter to PATH in profile
    echo "" >> "$PROFILE_FILE"
    echo "# Flutter PATH - added by Gloomhaven Monster Recognizer setup" >> "$PROFILE_FILE"
    echo "export PATH=\"$FLUTTER_PATH:\$PATH\"" >> "$PROFILE_FILE"
    echo "Flutter PATH added to $PROFILE_FILE"
fi

echo ""
echo "To apply changes to current session, run:"
echo "source $PROFILE_FILE"
echo ""
echo "Or restart your terminal for permanent effect." 