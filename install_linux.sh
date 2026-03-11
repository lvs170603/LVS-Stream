#!/bin/bash

# Configuration
APP_NAME="LVS Live TV"
# Use the absolute path where the build artifacts currently reside
# Use the custom installation path
INSTALL_DIR="/media/venkat/D Drive/softwares/live_tv"
EXEC_PATH="$INSTALL_DIR/live_tv"
ICON_PATH="$INSTALL_DIR/data/flutter_assets/assets/icon.png"
DESKTOP_FILE="$HOME/.local/share/applications/lvs_live_tv.desktop"

# Check if build exists
if [ ! -f "$EXEC_PATH" ]; then
    echo "Error: Application executable not found at $EXEC_PATH"
    echo "Please build the app first using 'flutter build linux --release'"
    exit 1
fi

# Ensure local applications directory exists
mkdir -p "$HOME/.local/share/applications"

# Create the .desktop file
echo "Creating desktop entry..."
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Watch Live TV Channels
Exec="$EXEC_PATH"
Icon=$ICON_PATH
Categories=AudioVideo;Video;Player;TV;
Terminal=false
StartupNotify=true
EOF

# Make it executable
chmod +x "$DESKTOP_FILE"

echo "✅ Installed successfully!"
echo "------------------------------------------------"
echo "You can now search for '$APP_NAME' in your Ubuntu applications menu."
echo "Or launch it immediately by running: $DESKTOP_FILE"
