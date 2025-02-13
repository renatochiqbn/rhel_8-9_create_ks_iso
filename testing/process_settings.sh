#!/bin/bash
# process_settings.sh - Script 2: Uses the settings file

# Get settings file from script 1
SETTINGS_FILE=$(cat .selected_settings)

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Settings file not found!"
    exit 1
fi

# Source the settings file
source "$SETTINGS_FILE"

# Example usage of settings
echo "Processing with following settings:"
echo "Project Name: $PROJECT_NAME"
echo "Output Directory: $OUTPUT_DIR"

# Check toggle options
[ "${DEBUG:-false}" = "true" ] && echo "Debug mode: Enabled"
[ "${LOGGING:-false}" = "true" ] && echo "Logging: Enabled"
[ "${VERBOSE:-false}" = "true" ] && echo "Verbose output: Enabled"
[ "${BACKUP:-false}" = "true" ] && echo "Automatic backup: Enabled"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Add your processing logic here
# ...

echo "Processing complete!"