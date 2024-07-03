#!/bin/bash

# Configuration
remote=origin
branch=master
chunk_size=50  # Number of files to commit at once
local_directory="/home/mattson/Documents/GOVT"
repo_url="https://github.com/ChattMenard/Canadian-Law"
api_url="https://api.github.com/repos/ChattMenard/Canadian-Law/contents"
auth_token="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"  # Replace with your GitHub token

# Ensure Git LFS is tracking PDF files
git lfs track "*.pdf"
git add .gitattributes
git commit -m "Track PDF files with Git LFS"
git push "$remote" "$branch"

# Initial commit for the script and log file
git add upload_pdfs.sh splitlawpdfs/process_log.log
git commit -m "Add upload script and process log"
git push "$remote" "$branch"

# Exclude script and log file from future commits
echo "upload_pdfs.sh" >> .gitignore
echo "splitlawpdfs/process_log.log" >> .gitignore
git add .gitignore
git commit -m "Exclude upload script and process log from future commits"
git push "$remote" "$branch"

# Function to get the list of files from GitHub
get_github_files() {
  echo "Fetching file list from GitHub..."
  curl -s -H "Authorization: token $auth_token" "$api_url" | jq -r '.[].name'
}

# Function to get the list of local PDF files
get_local_files() {
  echo "Fetching local PDF file list..."
  find "$local_directory" -type f -name "*.pdf"
}

# Function to add files in chunks and commit them
commit_in_chunks() {
  total_files=$(echo "$files_to_upload" | wc -l)
  if [ "$total_files" -eq 0 ]; then
    echo "No new PDF files to commit."
    exit 0
  fi

  echo "Total new PDF files to commit: $total_files"

  i=0
  while IFS= read -r file; do
    echo "Adding file: $file"
    git add "$file"
    i=$((i + 1))

    # Update progress
    progress=$((i * 100 / total_files))
    echo -ne "Progress: $progress% ($i/$total_files)\r"

    if [ $((i % chunk_size)) -eq 0 ]; then
      echo -ne "\nCommitting chunk of $chunk_size files...\n"
      git commit -m "Partial commit - chunk $((i / chunk_size))"
      git push "$remote" "$branch"
      git reset HEAD  # Unstage all files for the next chunk
    fi
  done <<< "$files_to_upload"

  # Commit any remaining files
  if [ $((i % chunk_size)) -ne 0 ]; then
    echo -ne "\nCommitting final chunk of $((i % chunk_size)) files...\n"
    git commit -m "Final partial commit"
    git push "$remote" "$branch"
  fi

  echo "All files committed and pushed successfully."
}

# Increase Git buffer size
echo "Increasing Git buffer size..."
git config --global http.postBuffer 524288000

# Check if we are in a Git repository
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Starting to commit in chunks..."

  # Get list of files from GitHub and local directory
  github_files=$(get_github_files)
  local_files=$(get_local_files)

  # Find files that are in the local directory but not on GitHub
  echo "Comparing local files with GitHub files..."
  files_to_upload=$(comm -23 <(echo "$local_files" | sort) <(echo "$github_files" | sort))

  # Commit and push files in chunks
  commit_in_chunks
else
  echo "Error: Not inside a Git repository. Please navigate to the root directory of your Git repository and try again."
fi

