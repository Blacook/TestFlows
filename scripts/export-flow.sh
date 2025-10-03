# scripts/export-flow.sh
#!/bin/bash

set -e

# .envファイルから設定を読み込み
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

FLOW_ID=${1:-$FLOW_ID}
REGION=${AWS_REGION:-us-east-1}
OUTPUT_FILE=${2:-"exported-flow-$(date +%Y%m%d-%H%M%S).json"}

if [ -z "$FLOW_ID" ]; then
  echo "❌ Error: FLOW_ID not provided"
  echo "Usage: ./scripts/export-flow.sh <FLOW_ID> [output-file]"
  echo "Or set FLOW_ID in .env file"
  exit 1
fi

echo "📥 Exporting Flow: $FLOW_ID"
echo "📍 Region: $REGION"

# フロー定義をエクスポート
aws bedrock-agent get-flow \
  --flow-identifier "$FLOW_ID" \
  --region "$REGION" \
  --query 'definition' \
  --output json > "$OUTPUT_FILE"

echo "✅ Flow exported to: $OUTPUT_FILE"

# フロー情報も別途保存
aws bedrock-agent get-flow \
  --flow-identifier "$FLOW_ID" \
  --region "$REGION" \
  > "flow-metadata-$(date +%Y%m%d-%H%M%S).json"

echo "✅ Flow metadata saved"
