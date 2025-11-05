#!/bin/bash

# Test script for BrowseForward API
# Replace YOUR-PROJECT with your actual Vercel URL after deployment

BASE_URL="https://YOUR-PROJECT.vercel.app/api/browse-content"

echo "Testing BrowseForward API..."
echo ""

echo "1. Testing browse-queue endpoint with category filter:"
curl -s "$BASE_URL?category=Science&limit=2&isActiveOnly=true" | python3 -m json.tool | head -30
echo ""

echo "2. Testing categories endpoint:"
curl -s "$BASE_URL?endpoint=categories" | python3 -m json.tool
echo ""

echo "3. Testing subcategories endpoint:"
curl -s "$BASE_URL?endpoint=subcategories&category=Science" | python3 -m json.tool
echo ""

echo "Done!"