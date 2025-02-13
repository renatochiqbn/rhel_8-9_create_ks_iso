#!/bin/bash
# create_all.sh - Main script that orchestrates the process

# Make scripts executable
chmod +x settings_manager.sh process_settings.sh

# Run settings manager first
./settings_manager.sh

# Check if settings file was successfully created/loaded
if [ $? -eq 0 ]; then
    # Run the processing script
    ./process_settings.sh
else
    echo "Settings configuration failed. Exiting."
    exit 1
fi
