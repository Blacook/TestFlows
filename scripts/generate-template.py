#!/usr/bin/env python3
"""
テンプレートファイルから環境変数を展開してファイルを生成
単一ファイルまたはディレクトリ全体を処理可能
"""
import os
import sys
import json
from pathlib import Path

def process_template(template_file, output_file):
    """テンプレートファイルを処理して出力"""
    with open(template_file, 'r') as f:
        content = f.read()
    
    for key, value in os.environ.items():
        content = content.replace(f'${key}', value).replace(f'${{{key}}}', value)
    
    json.loads(content)
    
    with open(output_file, 'w') as f:
        f.write(content)

def main():
    if len(sys.argv) != 3:
        print("Usage: generate-template.py <template-file-or-dir> <output-file-or-dir>", file=sys.stderr)
        sys.exit(1)
    
    source = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    
    try:
        if source.is_file():
            process_template(source, dest)
        elif source.is_dir():
            dest.mkdir(parents=True, exist_ok=True)
            for template_file in source.glob('*.json'):
                output_file = dest / template_file.name
                process_template(template_file, output_file)
        else:
            print(f"Error: {source} not found", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
