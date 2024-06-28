#!/usr/bin/env sh

# Get the last tag (if any)
last_tag=$(git describe --tags --abbrev=0 2>/dev/null)

# Get the current date
date=$(date +'%Y-%m-%d')

# Function to extract commit messages
extract_commits() {
    if [ -n "$last_tag" ]; then
        git log ${last_tag}..HEAD --pretty=format:"%s"
    else
        # No tags found, get all commits
        git log --pretty=format:"%s"
    fi
}

# Extract and categorize commits
commits=$(extract_commits)
new_feats=""
fixes=""
improvements=""

while read -r commit; do
    if [[ $commit == *"feat:"* ]]; then
        new_feats+="  - ${commit#*feat: }\n"
    elif [[ $commit == *"fix:"* ]]; then
        fixes+="  - ${commit#*fix: }\n"
    elif [[ $commit == *"tweak:"* ]]; then
        improvements+="  - ${commit#*tweak: }\n"
    fi
done <<< "$commits"

# Check if there are any categorized commits
if [ -z "$new_feats" ] && [ -z "$fixes" ] && [ -z "$improvements" ]; then
    echo "No new commits to add."
    exit 0
fi

# Format the output
output="** tag [$date]\n"
if [ -n "$new_feats" ]; then
    output+="*** New\n$new_feats"
fi
if [ -n "$fixes" ]; then
    output+="*** Fixes\n$fixes"
fi
if [ -n "$improvements" ]; then
    output+="*** Improvements\n$improvements"
fi

# Print the output
echo -e "$output"
