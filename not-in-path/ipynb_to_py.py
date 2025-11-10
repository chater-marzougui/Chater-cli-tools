#! python
"""Convert a Jupyter notebook (.ipynb) to a structured .txt file for LLM processing.
Each cell is marked with its type (markdown or code) and a prompt is added at the end
to guide the LLM in converting back to notebook format.
"""
import json
import sys

CODE_MARKER = '# CODE:'
MD_MARKER = '# MD:'

def load_notebook(ipynb_file):
    """Load a Jupyter notebook from a .ipynb file."""
    try:
        with open(ipynb_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: File '{ipynb_file}' not found.")
        return None
    except json.JSONDecodeError:
        print(f"Error: '{ipynb_file}' is not a valid JSON file.")
        return None


def put_in_clipboard(txt_content):
    try:
        import pyperclip
        pyperclip.copy(txt_content)
        return " (also copied to clipboard)"
    except ImportError:
        return " (install 'pyperclip' to enable clipboard copy)"


def get_content_as_string(source, cell_type):
    
    pad = '' if cell_type == 'code' else '#: '
    if isinstance(source, list):
        return pad.join(source)
    
    if cell_type == 'code':
        return source
    
    lst = source.splitlines(keepends=True)
    return ''.join([pad + line for line in lst])

def ipynb_to_txt(ipynb_file, output_file=None):
    """Convert a .ipynb notebook to .txt file with structure markers."""
    
    # Read the notebook file
    notebook = load_notebook(ipynb_file)
    if notebook is None:
        return
    
    # Extract cells
    cells = notebook.get('cells', [])
    
    # Build text content
    txt_lines = []
    
    for i, cell in enumerate(cells):
        cell_type = cell.get('cell_type', 'code')
        source = cell.get('source', [])
        
        # Convert source to string if it's a list
        content = get_content_as_string(source, cell_type)

        # Skip empty cells
        if not content.strip():
            continue
        
        if cell_type == 'markdown':
            txt_lines.append("# MD:")
        elif cell_type == 'code':
            txt_lines.append("# CODE:")
            
        txt_lines.append(content)
        
        # Add spacing between cells
        if i < len(cells) - 1:
            txt_lines.append("")
    
    # Add the prompt at the end
    prompt = """

---
When generating a python code dedicated for Jupyter Notebook, structure your response as follows:

For markdown cells, use:
# MD: 
#: Markdown content here
#: Additional markdown here.

For code cells, use:
# CODE:
your_code_here()
additional_code_here()

In both cases, ensure you return to line after the marker.
Each line of markdown should start with #: to indicate it's part of the markdown cell.
"""
    
    txt_lines.append(prompt)
    
    # Combine all lines
    txt_content = '\n'.join(txt_lines)
    
    # Determine output filename
    if output_file is None:
        output_file = ipynb_file.rsplit('.', 1)[0] + '.txt'
    
    # Write to txt file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(txt_content)
        
    # Copy into clipboard (optional, requires pyperclip)
    clipboard_msg = put_in_clipboard(txt_content)
    
    
    print(f"Successfully created '{output_file}'")
    print(f"Total cells extracted: {len([c for c in cells if c.get('source')])}")
    print("\nYou can now share this .txt file with an LLM for modifications.")
    print(clipboard_msg)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ipynb_to_py.py <input.ipynb> [output.txt]")
        print("\nThis will create a .txt file with:")
        print("- Markdown cells marked with '# MD:'")
        print("- Code cells marked with '# CODE:'")
        print("- A prompt at the end for LLM instructions")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    ipynb_to_txt(input_file, output_file)