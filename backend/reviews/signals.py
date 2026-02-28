from django.db.models import Avg, Count
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver

from .models import Review


def _recalculate_product(product):
    """Recompute avg_rating and review_count on a Product and save."""
    agg = Review.objects.filter(product=product).aggregate(
        avg=Avg('rating'),
        cnt=Count('id'),
    )
    product.avg_rating = round(agg['avg'] or 0, 2)
    product.review_count = agg['cnt'] or 0
    product.save(update_fields=['avg_rating', 'review_count'])


def _recalculate_vendor(vendor):
    """Recompute avg_rating and review_count on a Vendor and save.

    A vendor's aggregate is the mean across all reviews for their products.
    """
    from reviews.models import Review as R  # avoid circular import at module level
    agg = R.objects.filter(product__vendor=vendor).aggregate(
        avg=Avg('rating'),
        cnt=Count('id'),
    )
    vendor.avg_rating = round(agg['avg'] or 0, 2)
    vendor.review_count = agg['cnt'] or 0
    vendor.save(update_fields=['avg_rating', 'review_count'])


@receiver(post_save, sender=Review)
def review_saved(sender, instance, **kwargs):
    _recalculate_product(instance.product)
    if hasattr(instance.product, 'vendor') and instance.product.vendor:
        _recalculate_vendor(instance.product.vendor)


@receiver(post_delete, sender=Review)
def review_deleted(sender, instance, **kwargs):
    _recalculate_product(instance.product)
    if hasattr(instance.product, 'vendor') and instance.product.vendor:
        _recalculate_vendor(instance.product.vendor)
