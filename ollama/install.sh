#!/bin/bash

ENV_FILE="$HOME/.config/ollama/ollama.env"
TEMPLATE_FILE="$HOME/.config/ollama/ollama.env.template"

if [ ! -f "$ENV_FILE" ]; then
	echo "⚠️  $ENV_FILE not found (only the template is present)."
	echo "   Run: cp $TEMPLATE_FILE $ENV_FILE"
	echo "   Then edit it and paste your OLLAMA_API_KEY."
fi
