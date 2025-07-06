# Flutter environment setup script
# Use with: source app/setup-env.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add Flutter to PATH
export PATH="$SCRIPT_DIR/flutter/bin:$PATH"
