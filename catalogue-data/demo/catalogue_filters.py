"""Listing-based shoe categories shared by catalog serving and AI filtering."""
import re

GENDER_FILTERS = {'all', 'men', 'women'}


def shoe_gender(title):
    title = title.lower()
    men = bool(re.search(r"\b(?:men(?:['’]?s)?|male)\b", title))
    women = bool(re.search(r"\b(?:women(?:['’]?s)?|female)\b", title))
    if re.search(r'\bunisex\b', title) or (men and women):
        return 'unisex'
    return 'men' if men else 'women' if women else 'unspecified'


def matches_gender(product, selection):
    return selection == 'all' or product.get('gender', shoe_gender(product['title'])) in {selection, 'unisex'}
