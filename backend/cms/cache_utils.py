from django.core.cache import cache

CMS_BOOTSTRAP_CACHE_KEY = 'cms:bootstrap:v1'
CMS_PAGE_CACHE_KEY_PREFIX = 'cms:page:'


def cms_page_cache_key(identifier: str) -> str:
    return f'{CMS_PAGE_CACHE_KEY_PREFIX}{identifier}'


def invalidate_cms_cache() -> None:
    cache.delete(CMS_BOOTSTRAP_CACHE_KEY)
    delete_pattern = getattr(cache, 'delete_pattern', None)
    if callable(delete_pattern):
        delete_pattern(f'{CMS_PAGE_CACHE_KEY_PREFIX}*')

