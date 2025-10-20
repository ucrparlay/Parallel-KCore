#!/usr/bin/env python
# encoding: utf-8

# Define the input and output file paths
input_file_path = 'com-youtube.ungraph.txt'
output_file_path = 'output.txt'

# Read the input file
with open(input_file_path, 'r') as file:
    lines = file.readlines()

# Open the output file to write the results
with open(output_file_path, 'w') as file:
    # Write the first line as it is
    file.write(lines[0])

    # Process the remaining lines
    for line in lines[1:]:
        numbers = line.split()
        modified_numbers = [str(int(number) - 1) for number in numbers]
        file.write(' '.join(modified_numbers) + '\n')

print("File processing complete. Check the output file.")

