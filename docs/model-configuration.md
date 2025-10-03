# モデル設定ガイド

## 概要

各Promptノードで異なるBedrockモデルを使用することで、レート制限を分散できます。

## 環境変数

`.env`ファイルで以下の変数を設定：

```bash
# 各ノード用のモデルID
MODEL_ID_ANALYZER=anthropic.claude-3-haiku-20240307-v1:0
MODEL_ID_EXTRACTOR=anthropic.claude-3-sonnet-20240229-v1:0
MODEL_ID_REPORT=anthropic.claude-3-haiku-20240307-v1:0
MODEL_ID_KNOWLEDGE_BASE=anthropic.claude-3-haiku-20240307-v1:0
```

## 推奨構成

### パターン1: レート制限分散（推奨）
```bash
MODEL_ID_ANALYZER=anthropic.claude-3-haiku-20240307-v1:0
MODEL_ID_EXTRACTOR=anthropic.claude-3-sonnet-20240229-v1:0
MODEL_ID_REPORT=anthropic.claude-3-haiku-20240307-v1:0
MODEL_ID_KNOWLEDGE_BASE=anthropic.claude-3-haiku-20240307-v1:0
```

### パターン2: コスト最適化
```bash
MODEL_ID_ANALYZER=anthropic.claude-3-haiku-20240307-v1:0
MODEL_ID_EXTRACTOR=anthropic.claude-3-haiku-20240307-v1:0
MODEL_ID_REPORT=anthropic.claude-3-haiku-20240307-v1:0
MODEL_ID_KNOWLEDGE_BASE=anthropic.claude-3-haiku-20240307-v1:0
```

### パターン3: 高精度分析
```bash
MODEL_ID_ANALYZER=anthropic.claude-3-sonnet-20240229-v1:0
MODEL_ID_EXTRACTOR=anthropic.claude-3-sonnet-20240229-v1:0
MODEL_ID_REPORT=anthropic.claude-3-sonnet-20240229-v1:0
MODEL_ID_KNOWLEDGE_BASE=anthropic.claude-3-sonnet-20240229-v1:0
```

## 利用可能なモデル

- `anthropic.claude-3-haiku-20240307-v1:0` - 高速・低コスト
- `anthropic.claude-3-sonnet-20240229-v1:0` - バランス型
- `anthropic.claude-3-opus-20240229-v1:0` - 最高精度

## 再デプロイ

設定変更後は再デプロイが必要：

```bash
./scripts/deploy.sh
```
