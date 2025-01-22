#!/usr/bin/env python3

import os
import sys
try:
    from PIL import Image
except ImportError:
    print("Error: Pillow package not found. Please install it with:")
    print("pip install Pillow")
    sys.exit(1)

import yaml
import shutil
from pathlib import Path

class ImageHandler:
    def __init__(self):
        self.supported_formats = ['.jpg', '.jpeg', '.png', '.gif']
        
    def process_image(self, src_path, gallery, filename, caption='', copyright=''):
        try:
            # Verify source image exists
            if not os.path.exists(src_path):
                print(f"Error: Source image not found: {src_path}")
                return False
                
            # Open and verify image
            try:
                img = Image.open(src_path)
                img.verify()
            except Exception as e:
                print(f"Error: Invalid image file: {e}")
                return False
                
            # Create gallery directory if needed
            gallery_dir = os.path.join('images', 'albums', gallery)
            os.makedirs(gallery_dir, exist_ok=True)
            
            # Copy image to gallery
            dest_path = os.path.join(gallery_dir, filename)
            shutil.copy2(src_path, dest_path)
            
            # Update gallery index
            self.update_gallery_yaml(gallery, filename, caption, copyright)
            
            return True
            
        except Exception as e:
            print(f"Error processing image: {e}")
            return False
            
    def update_gallery_yaml(self, gallery, filename, caption='', copyright=''):
        try:
            index_file = os.path.join('images', gallery, 'index.html')
            
            if not os.path.exists(index_file):
                print(f"Error: Gallery index not found: {index_file}")
                return False
                
            # Read existing front matter
            with open(index_file) as f:
                content = f.read()
                
            parts = content.split('---', 2)
            if len(parts) < 3:
                print("Error: Invalid index.html format")
                return False
                
            # Parse front matter
            front_matter = yaml.safe_load(parts[1])
            
            # Preserve the order of fields
            field_order = [
                'layout',
                'title',
                'description',
                'active',
                'header-img',
                'album-title',
                'images'
            ]
            
            # Add image to list
            if 'images' not in front_matter:
                front_matter['images'] = []
                
            image_entry = {
                'image_path': f'/images/albums/{gallery}/{filename}',
                'caption': caption,
                'copyright': copyright
            }
            
            front_matter['images'].append(image_entry)
            
            # Create ordered dictionary
            ordered_front_matter = {}
            for field in field_order:
                if field in front_matter:
                    ordered_front_matter[field] = front_matter[field]
            
            # Add any remaining fields
            for key, value in front_matter.items():
                if key not in ordered_front_matter:
                    ordered_front_matter[key] = value
            
            # Write updated front matter with preserved formatting
            yaml_content = yaml.dump(ordered_front_matter, 
                                   default_flow_style=False, 
                                   allow_unicode=True, 
                                   sort_keys=False,
                                   width=float("inf"))  # Prevent line wrapping
            
            # Fix YAML formatting
            yaml_content = yaml_content.replace('header-img:', 'header-img: ')
            yaml_content = yaml_content.replace('album-title:', 'album-title: ')
            
            content = '---\n' + yaml_content + '---\n' + parts[2]
            
            with open(index_file, 'w') as f:
                f.write(content)
                
            return True
            
        except Exception as e:
            print(f"Error updating gallery YAML: {e}")
            return False

    def remove_image(self, gallery, filename):
        """Remove image and its entry from gallery"""
        try:
            # Remove file
            image_path = os.path.join('images', gallery, filename)
            if os.path.exists(image_path):
                os.remove(image_path)
            
            # Update YAML
            index_file = os.path.join('images', gallery, 'index.html')
            if not os.path.exists(index_file):
                return False
                
            # Read existing content
            with open(index_file) as f:
                content = f.read()
                
            parts = content.split('---', 2)
            
            front_matter = yaml.safe_load(parts[1])
            if 'images' in front_matter:
                front_matter['images'] = [
                    img for img in front_matter['images'] 
                    if not img['name'].endswith(filename)
                ]
                
            # Write back
            new_content = '---\n'
            new_content += yaml.dump(front_matter, allow_unicode=True, sort_keys=False)
            new_content += '---\n'
            new_content += parts[2]
            
            with open(index_file, 'w') as f:
                f.write(new_content)
            return True
            
        except Exception as e:
            print(f"Error removing image: {e}")
            return False

def main():
    if len(sys.argv) < 5:
        print("Usage: image_handler.py process|remove src_path gallery filename [caption] [copyright]")
        sys.exit(1)
        
    action = sys.argv[1]
    src_path = sys.argv[2]
    gallery = sys.argv[3]
    filename = sys.argv[4]
    caption = sys.argv[5] if len(sys.argv) > 5 else ''
    copyright = sys.argv[6] if len(sys.argv) > 6 else ''
    
    handler = ImageHandler()
    
    success = False
    if action == 'process':
        success = handler.process_image(src_path, gallery, filename, caption, copyright)
    elif action == 'remove':
        success = handler.remove_image(gallery, filename)
    else:
        print(f"Unknown action: {action}")
        sys.exit(1)
        
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main() 