#!/bin/bash

# Extract the ZIP file
if [ -f "blueprint-marketplace.zip" ]; then
    unzip -q blueprint-marketplace.zip
    echo "✓ ZIP file extracted successfully"
    
    # Show what was extracted
    echo "Extracted contents:"
    ls -la blueprint-marketplace/ | head -20
else
    echo "✗ blueprint-marketplace.zip not found"
    exit 1
fi
