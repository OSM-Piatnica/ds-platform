#!/bin/bash

echo "This script will permanently delete all data in the current project
directory."
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Get the directory of the script itself and delete it
    DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null & pwd)"
    echo "Deleting project directory: ${DIRECTORY}"
    rm -rf "${DIRECTORY}"
    echo "Project directory was deleted."
fi
