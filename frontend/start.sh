#!/bin/bash
set -e

echo "Building Next.js (production)..."
npm run build

echo "Starting frontend (production)..."
exec npm run start -- -H 0.0.0.0 -p 3000
