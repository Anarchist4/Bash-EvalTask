#!/bin/bash
read -p "Enter the directory path to be monitored: " directory
read -p "Enter a regular expression pattern to match the file names to be monitored (e.g. .*\.txt$): " regex_pattern
if ! [[ "$regex_pattern" =~ ^.*\.(txt)$ ]]; then
  echo "Error: Invalid file pattern. Please enter a pattern that matches files with a .txt extension."
  exit 1
fi

function on_file_change {
	local file="$1"
	echo "File $file has been changed"
	if grep -q "error" "$file"; then
        # Use awk to extract specific values from the line containing the string.
        awk '/error/ {print $1, $2, $4}' "$file"
        # Use cp to create a backup of the file in a separate backup directory.
        backup_dir="backup"
        mkdir -p "$backup_dir"
        backup_file="$backup_dir/$(date '+%Y-%m-%d-%H-%M-%S')-$(basename $file)"
        cp "$file" "$backup_file"

        # Use sed to modify the contents of the file by replacing the specific string with a new value.
        sed -i 's/error/warning/g' "$file"

        # If the modified file contains more than 10 lines, use head and tail to extract the first 5 and last 5 lines, respectively, and save them to a separate file.
        line_count=$(wc -l < "$file")
        if ((line_count > 10)); then
            head -5 "$file" > "${file}.head"
            tail -5 "$file" > "${file}.tail"
        fi

        # Use tar to compress the backup directory and save it with a timestamp in the filename.
        tar -czf "${backup_dir}_$(date '+%Y-%m-%d-%H-%M-%S').tar.gz" "$backup_dir"
    fi
}

# Use inotifywait to monitor the specified directory for changes to the files matching the specified regular expression pattern.
inotifywait -m -r -e modify,create,delete --format '%w%f' "$directory" | grep --line-buffered "$regex_pattern" | while read -r changed_file; do
   on_file_change  "$changed_file"
done

