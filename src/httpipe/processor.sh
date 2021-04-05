#!/bin/bash

set -o errexit
set -o nounset
shopt -s expand_aliases

alias echo='echo [HTTPIPE/NOP-PROC]'

echo "Starting httpipe default processor"
echo "This script just transfers data from \${HTTPIPE_INPUT_DIR} to \${HTTPIPE_OUTPUT_DIR}"
echo ""
echo "Printing configuration:"
echo "HTTPIPE_INPUT_DIR  = '${HTTPIPE_INPUT_DIR}'"
echo "HTTPIPE_OUTPUT_DIR = '${HTTPIPE_OUTPUT_DIR}'"
echo ""

cp -ra "${HTTPIPE_INPUT_DIR}" "${HTTPIPE_OUTPUT_DIR}"

echo "Done !"
