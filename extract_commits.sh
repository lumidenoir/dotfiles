#!/usr/bin/env sh

# Get the last two tags
last_two_tags=$(git tag --sort=-creatordate | head -n 2)
tag1=$(echo "$last_two_tags" | sed -n '1p')
tag2=$(echo "$last_two_tags" | sed -n '2p')

# Get the current date
date=$(date +'%Y-%m-%d')

# Function to extract commit messages
extract_commits() {
    if [ -z "$tag2" ]; then
        # Only one tag found, get all commits up to that tag
        git log $tag1 --pretty=format:"%s"
    else
        # Two tags found, get commits between the two tags
        git log $tag2..$tag1 --pretty=format:"%s"
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
output="** $tag1 [$date]\n"
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
