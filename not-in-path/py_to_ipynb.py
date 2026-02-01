#! python
"""Convert a .txt file to Jupyter notebook (.ipynb) format.
The .txt file should have cells marked with:
- # MD: for markdown cells
- # CODE: for code cells
"""

import json
import sys

CODE_MARKER = '# CODE:'
MD_MARKER = '# MD:'
EXACT_STRING = "When generating a python code dedicated for Jupyter Notebook, structure your response as follows:"

def get_line_type(lines, index):
    """Determine if line is a marker for code or markdown."""
    if index >= len(lines):
        return None, None
    line = lines[index]
    stripped = line.strip()
    if stripped.startswith(MD_MARKER):
        return 'md', line[line.index(MD_MARKER) + len(MD_MARKER):].lstrip()
    elif stripped.startswith(CODE_MARKER):
        return 'code', None
    else:
        return None, line

def parse_txt_to_cells(txt_content):
    """Parse text content into notebook cells."""
    lines = txt_content.split('\n')
    cells = []
    
    last_line_type = 'code'
    code_lines = []
    md_lines = []
    
    i = 0
    while i < len(lines) + 1:
        current_type, content = get_line_type(lines, i)
        
        # Save accumulated lines when type changes or at end
        if (current_type is not None) or i == len(lines):
            if last_line_type == 'code' and code_lines:
                cells.append({
                    "cell_type": "code",
                    "execution_count": None,
                    "metadata": {},
                    "outputs": [],
                    "source": '\n'.join(code_lines).rstrip()
                })
                code_lines = []
            elif last_line_type == 'md' and md_lines:
                cells.append({
                    "cell_type": "markdown",
                    "metadata": {},
                    "source": '\n'.join(md_lines).rstrip()
                })
                md_lines = []
            
        if i == len(lines): break

        if content is not None and last_line_type == 'md' and '---' in content:
            _, next_content = get_line_type(lines, i+1)
            if next_content is not None and EXACT_STRING in next_content:
                i += 15
                continue
            
        
        # Add content to appropriate buffer
        if current_type != None:
            last_line_type = current_type
        else:
            # No marker detected, use last type
            if last_line_type == 'code':
                code_lines.append(content)
            else:
                if content.startswith('#: '):
                    md_lines.append(content[3:])
                else:
                    md_lines.append(content)
        
        i += 1
    
    return cells

def txt_to_ipynb(txt_file, output_file=None):
    """Convert a .txt file to .ipynb notebook format."""
    
    try:
        with open(txt_file, 'r', encoding='utf-8') as f:
            txt_content = f.read()
    except FileNotFoundError:
        print(f"Error: File '{txt_file}' not found.")
        return
    
    cells = parse_txt_to_cells(txt_content)
    
    notebook = {
        "cells": cells,
        "metadata": {
            "kernelspec": {
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            },
            "language_info": {
                "codemirror_mode": {
                    "name": "ipython",
                    "version": 3
                },
                "file_extension": ".py",
                "mimetype": "text/x-python",
                "name": "python",
                "nbconvert_exporter": "python",
                "pygments_lexer": "ipython3",
                "version": "3.8.0"
            }
        },
        "nbformat": 4,
        "nbformat_minor": 4
    }
    
    if output_file is None:
        output_file = txt_file.rsplit('.', 1)[0] + '.ipynb'
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(notebook, f, indent=2)
    
    print(f"Successfully created '{output_file}'")
    print(f"Total cells: {len(cells)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python py_to_ipynb.py <input.txt> [output.ipynb]")
        print(f"\nFormat: {MD_MARKER} for markdown, {CODE_MARKER} for code")
        sys.exit(1)
    
    if sys.argv[1].endswith('.ipynb'):
        print("Error: Input file must be a .txt or .py file.")
        sys.exit(1)
        
    txt_to_ipynb(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)