#!/bin/bash

# ポリシーテンプレートから.envの値を使って実際のポリシーを生成

set -e

if [ -f ".env" ]; then
    set -a
    source .env
    set +a
else
    echo "❌ .env ファイルが見つかりません"
    exit 1
fi

POLICY_DIR="config/iam-policies"
OUTPUT_DIR="generated-policies"

[ -d "$OUTPUT_DIR" ] && rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for template in "$POLICY_DIR"/*.json; do
    [ -f "$template" ] || continue
    filename=$(basename "$template")
    output="$OUTPUT_DIR/$filename"
    
    python3 -c "
import os
import sys
import json

try:
    with open('$template', 'r') as f:
        content = f.read()
    
    for key, value in os.environ.items():
        content = content.replace(f'\${key}', value).replace(f'\${{{key}}}', value)
    
    json.loads(content)
    
    with open('$output', 'w') as f:
        f.write(content)
except Exception as e:
    print(f'Error processing $template: {e}', file=sys.stderr)
    sys.exit(1)
"
    echo "✅ $filename を生成しました"
done

echo "🎉 全てのポリシーファイルを $OUTPUT_DIR に生成しました"
