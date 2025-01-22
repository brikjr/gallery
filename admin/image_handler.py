import os
import sys
from PIL import Image
import yaml
import shutil
from pathlib import Path

class ImageHandler:
    def __init__(self, base_path):
        self.base_path = Path(base_path)
        
    def process_image(self, image_path, gallery, filename):
        """Process and optimize image before saving"""
        try:
            with Image.open(image_path) as img:
                # Convert RGBA to RGB if needed
                if img.mode in ('RGBA', 'LA'):
                    background = Image.new('RGB', img.size, (255, 255, 255))
                    background.paste(img, mask=img.split()[-1])
                    img = background
                
                # Optimize image
                output_path = self.base_path / 'images' / 'albums' / gallery / filename
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                img.save(str(output_path), 
                        'JPEG', 
                        quality=85, 
                        optimize=True,
                        progressive=True)
                
                return True
        except Exception as e:
            print(f"Error processing image: {e}", file=sys.stderr)
            return False

    def update_gallery_yaml(self, gallery, filename, caption, copyright):
        """Update gallery index.html with new image"""
        try:
            gallery_path = self.base_path / 'images' / gallery / 'index.html'
            
            if not gallery_path.exists():
                return False
                
            # Read current content
            content = gallery_path.read_text(encoding='utf-8')
            
            # Find YAML front matter
            parts = content.split('---', 2)
            if len(parts) < 3:
                return False
                
            # Parse YAML
            front_matter = yaml.safe_load(parts[1])
            
            # Add new image
            if 'images' not in front_matter:
                front_matter['images'] = []
                
            new_image = {
                'image_path': f'/images/albums/{gallery}/{filename}',
                'caption': caption or filename,
                'copyright': f'© {copyright}' if copyright else '© Brik'
            }
            
            front_matter['images'].append(new_image)
            
            # Write back
            new_content = '---\n'
            new_content += yaml.dump(front_matter, allow_unicode=True, sort_keys=False)
            new_content += '---\n'
            new_content += parts[2]
            
            gallery_path.write_text(new_content, encoding='utf-8')
            return True
            
        except Exception as e:
            print(f"Error updating YAML: {e}", file=sys.stderr)
            return False

    def remove_image(self, gallery, filename):
        """Remove image and its entry from gallery"""
        try:
            # Remove file
            image_path = self.base_path / 'images' / 'albums' / gallery / filename
            if image_path.exists():
                image_path.unlink()
            
            # Update YAML
            gallery_path = self.base_path / 'images' / gallery / 'index.html'
            if not gallery_path.exists():
                return False
                
            content = gallery_path.read_text(encoding='utf-8')
            parts = content.split('---', 2)
            
            front_matter = yaml.safe_load(parts[1])
            if 'images' in front_matter:
                front_matter['images'] = [
                    img for img in front_matter['images'] 
                    if not img['image_path'].endswith(filename)
                ]
                
            new_content = '---\n'
            new_content += yaml.dump(front_matter, allow_unicode=True, sort_keys=False)
            new_content += '---\n'
            new_content += parts[2]
            
            gallery_path.write_text(new_content, encoding='utf-8')
            return True
            
        except Exception as e:
            print(f"Error removing image: {e}", file=sys.stderr)
            return False

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['process', 'remove'])
    parser.add_argument('image_path')
    parser.add_argument('gallery')
    parser.add_argument('filename')
    parser.add_argument('caption', nargs='?', default='')
    parser.add_argument('copyright', nargs='?', default='')
    
    args = parser.parse_args()
    
    handler = ImageHandler(os.path.dirname(os.path.dirname(__file__)))
    
    if args.action == 'process':
        success = handler.process_image(args.image_path, args.gallery, args.filename)
        if success:
            success = handler.update_gallery_yaml(
                args.gallery, args.filename, args.caption, args.copyright)
    else:
        success = handler.remove_image(args.gallery, args.filename)
        
    sys.exit(0 if success else 1) 