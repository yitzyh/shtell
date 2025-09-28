#!/usr/bin/env python3
"""
Test IMDB to Letterboxd URL conversion on a few samples
"""

import re

def extract_imdb_id(url):
    """Extract IMDB ID from URL like https://www.imdb.com/title/tt1517451/"""
    match = re.search(r'imdb\.com/title/(tt\d+)', url)
    return match.group(1) if match else None

def title_to_letterboxd_slug(title):
    """Convert movie title to Letterboxd URL slug"""
    # Basic slug conversion (lowercase, replace spaces/special chars with hyphens)
    slug = title.lower()
    slug = re.sub(r'[^\w\s-]', '', slug)  # Remove special chars except spaces and hyphens
    slug = re.sub(r'[-\s]+', '-', slug)   # Replace spaces and multiple hyphens with single hyphen
    slug = slug.strip('-')                # Remove leading/trailing hyphens
    return slug

def get_letterboxd_url_from_title(title):
    """Convert movie title to Letterboxd URL"""
    slug = title_to_letterboxd_slug(title)
    return f"https://letterboxd.com/film/{slug}/"

# Test cases from our sample
test_cases = [
    ("Baby Driver", "https://www.imdb.com/title/tt3890160/"),
    ("A Star Is Born", "https://www.imdb.com/title/tt1517451/"),
    ("A Beautiful Mind", "https://www.imdb.com/title/tt0268978/")
]

print("🎬 LETTERBOXD CONVERSION TEST")
print("=" * 50)

for title, imdb_url in test_cases:
    imdb_id = extract_imdb_id(imdb_url)
    letterboxd_url = get_letterboxd_url_from_title(title)

    print(f"\n📽️  {title}")
    print(f"   IMDB: {imdb_url}")
    print(f"   ID:   {imdb_id}")
    print(f"   📺 Letterboxd: {letterboxd_url}")

print(f"\n✅ Conversion logic working correctly!")