# swift test -v &> test-result.txt

# # Append delimiter
# echo "\n--- SOURCE CODE ---\n" >> test-result.txt

# # Append the source file
# SOURCE_FILE="Tests/ParsersTests/dynparsable-tests.swift"
# cat $SOURCE_FILE >> test-result.txt

# echo "\n--- NOTE ---\n" >> test-result.txt
# cat notes.txt >> test-result.txt

# cat test-result.txt | pbcopy

# echo "Result should be copied"


# Run tests verbosely and filter from "Build complete" onwards
swift test -v 2>&1 | sed -n '/Build complete/,$p' > test-result.txt

# Append delimiter
echo -e "\n--- SOURCE CODE ---\n" >> test-result.txt

# Append the source file
SOURCE_FILE="Tests/ParsersTests/dynparsable-tests.swift"
cat $SOURCE_FILE >> test-result.txt

echo -e "\n--- NOTE ---\n" >> test-result.txt
cat notes.txt >> test-result.txt

# Copy to clipboard
cat test-result.txt | pbcopy

echo "Result copied to clipboard (filtered from 'Build complete' onwards)"
