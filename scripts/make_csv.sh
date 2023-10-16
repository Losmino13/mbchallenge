#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install jq first."
    exit 1
fi

# Input JSON file and output CSV file
json_file="user.json"
csv_file="output.csv"

# Extract headers from the JSON data
headers=$(jq -r '.data[0] | keys_unsorted | @csv' "$json_file")

# Extract values for each row
rows=$(jq -r '.data[] | [.id, .email, .first_name, .last_name, .avatar] | @csv' "$json_file")

# Combine headers and rows and write to CSV file
echo "$headers" > "$csv_file"
echo "$rows" >> "$csv_file"

# Remove double quotes from CSV file
tr -d '"' < "$csv_file" > "${csv_file%.csv}_no_quotes.csv"

echo "CSV file generated: $csv_file"