#!/bin/bash

# Guard hook: block npm/yarn/pnpm/bun install commands
# Reads command from stdin JSON, responds with permission JSON on stdout

# Read all of stdin (Cursor sends JSON payload)
input=$(cat)

# Extract the command using grep (no jq dependency needed)
command=$(echo "$input" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')

if echo "$command" | grep -qE '\b(npm|yarn|pnpm|bun)\s+(install|i|add|dlx)\b'; then
  echo '{"permission":"deny","agentMessage":"Blocked: adding new dependencies is not allowed. Use existing packages or built-in APIs like Intl.DateTimeFormat."}'
  exit 0
fi

# Allow everything else
echo '{"permission":"allow"}'
