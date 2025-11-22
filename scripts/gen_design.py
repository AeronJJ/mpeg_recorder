import sys
import os
import shutil
import re

def list_files_recursive(path='.'):
    file_paths = []
    
    for entry in os.listdir(path):
        full_path = os.path.join(path, entry)
        if os.path.isdir(full_path):
            file_paths.extend(list_files_recursive(full_path))
        else:
            file_paths.append(full_path)

    return file_paths

TEMPLATE = '../utils/design_template'
REPLACE_PATTERN = '**HDL_NAME**'
REGEX_PATTERN = re.escape(REPLACE_PATTERN)

def copy_template_to(name):
    dest_dir = os.path.join('./', name)
    if os.path.exists(dest_dir):
        print(f"Design {name} already exists. Skipping.")
        return

    try:
        shutil.copytree(TEMPLATE, dest_dir)
    except Exception as e:
        print(f"Error copying template to {dest_dir}: {e}")

    file_paths = list_files_recursive(dest_dir)
    for file_p in file_paths:
        # print(file_p)
        new_name = file_p.replace(REPLACE_PATTERN, name)
        os.rename(file_p, new_name)
        with open(new_name, "r+", encoding="utf-8") as f:
            text = f.read()
            new_text = re.sub(REGEX_PATTERN, name, text)
            f.seek(0)
            f.write(new_text)
            f.truncate()
        
def main():
    if len(sys.argv) < 2:
        print("Usage: python gen_design.py name1 name2 name3")
        return

    for design in sys.argv[1:]:
        copy_template_to(design)

if __name__ == '__main__':
    main()
