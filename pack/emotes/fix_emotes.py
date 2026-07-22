import os
import json
import glob

def fix_emotes():
    emotes_dir = r"c:\Users\brian\AppData\Roaming\.minecraft\2026UNIPruebas\emotes"
    files = glob.glob(os.path.join(emotes_dir, "*.json"))
    fixed_count = 0
    
    for file_path in files:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            modified = False
            if "name" in data and isinstance(data["name"], dict) and "fallback" in data["name"]:
                data["name"] = data["name"]["fallback"]
                modified = True
                
            if modified:
                with open(file_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=4, ensure_ascii=False)
                fixed_count += 1
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            
    print(f"Fixed {fixed_count} emote files successfully.")

if __name__ == "__main__":
    fix_emotes()
