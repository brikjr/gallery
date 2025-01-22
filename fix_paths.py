import os
import re
import yaml

def fix_paths_in_file(file_path):
    print(f"Processing {file_path}...")
    
    # Read the file content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split front matter and content
    parts = content.split('---', 2)
    if len(parts) < 3:
        print(f"No valid front matter found in {file_path}")
        return
    
    # Parse front matter
    front_matter = yaml.safe_load(parts[1])
    
    # Get gallery type from file path
    gallery_type = os.path.basename(os.path.dirname(file_path)).rstrip('s')  # Remove trailing 's'
    
    # Fix image paths in the front matter
    if 'images' in front_matter:
        for image in front_matter['images']:
            if 'image_path' in image:
                # Replace any variations of albums/landscapes or albums/portraits
                old_path = image['image_path']
                new_path = re.sub(
                    r'/albums/(?:landscape|landscapes|portrait|portraits)/',
                    f'/albums/{gallery_type}/',
                    old_path
                )
                image['image_path'] = new_path
    
    # Fix header-img if present
    if 'header-img' in front_matter:
        old_header = front_matter['header-img']
        new_header = re.sub(
            r'/albums/(?:landscape|landscapes|portrait|portraits)/',
            f'/albums/{gallery_type}/',
            old_header
        )
        front_matter['header-img'] = new_header
    
    # Reconstruct the file content
    new_content = '---\n' + yaml.dump(front_matter, allow_unicode=True) + '---' + parts[2]
    
    # Write back to file
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"Updated {file_path}")

def main():
    # Process landscape and portrait index files
    index_files = [
        'images/landscape/index.html',
        'images/portrait/index.html'
    ]
    
    for file_path in index_files:
        if os.path.exists(file_path):
            fix_paths_in_file(file_path)
        else:
            print(f"Warning: {file_path} not found")

if __name__ == '__main__':
    main() 