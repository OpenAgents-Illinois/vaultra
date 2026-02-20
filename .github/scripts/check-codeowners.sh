#!/bin/bash

# Checks if the GitHub actor is listed in CODEOWNERS.
# Sets GITHUB_OUTPUT allowed=true/false accordingly.

if grep -qE "(^|\s)@${ACTOR}(\s|$)" .github/CODEOWNERS; then
  echo "allowed=true" >> "$GITHUB_OUTPUT"
else
  echo "allowed=false" >> "$GITHUB_OUTPUT"
fi
