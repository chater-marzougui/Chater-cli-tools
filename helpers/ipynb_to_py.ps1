#!/usr/bin/env pwsh
# Wrapper for ipynb_to_txt.py
# Allows running it as: ipynb_to_txt file.ipynb [output.txt]

# Get the folder the python script lives in
$scriptDir = "C:\custom-scripts\not-in-path"

# Call the Python script with all the same arguments
python "$scriptDir\ipynb_to_py.py" @args
