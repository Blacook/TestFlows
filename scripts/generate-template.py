#!/usr/bin/env python3
"""
テンプレートファイルから環境変数を展開してファイルを生成
"""
import os
import sys
import json

def main():
    if len(sys.argv) != 3:
        print("Usage: generate-template.py <template-file> <output-file>", file=sys.stderr)
        sys.exit(1)
    
    template_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        with open(template_file, 'r') as f:
            content = f.read()
        
        # テンプレ内の変数を環境変数の値で置き換え
        for key, value in os.environ.items():
            content = content.replace(f'${key}', value).replace(f'${{{key}}}', value)
        
        json.loads(content)
        
        with open(output_file, 'w') as f:
            f.write(content)
            
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
