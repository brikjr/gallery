import os
import shutil

def rename_folders():
    base_dir = 'images/albums'
    
    # Dictionary of old folder names to new folder names
    folder_map = {
        'landscapes': 'landscape',
        'portraits': 'portrait'
    }
    
    for old_name, new_name in folder_map.items():
        old_path = os.path.join(base_dir, old_name)
        new_path = os.path.join(base_dir, new_name)
        
        if os.path.exists(old_path):
            try:
                # If new folder exists, merge contents
                if os.path.exists(new_path):
                    print(f"Merging {old_path} into {new_path}")
                    for item in os.listdir(old_path):
                        old_item = os.path.join(old_path, item)
                        new_item = os.path.join(new_path, item)
                        shutil.move(old_item, new_item)
                    os.rmdir(old_path)
                else:
                    # Simple rename if new folder doesn't exist
                    print(f"Renaming {old_path} to {new_path}")
                    os.rename(old_path, new_path)
                print(f"Successfully processed {old_name} -> {new_name}")
            except Exception as e:
                print(f"Error processing {old_name}: {str(e)}")
        else:
            print(f"Folder {old_path} not found - skipping")

if __name__ == '__main__':
    rename_folders() 