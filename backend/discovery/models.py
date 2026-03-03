from __future__ import annotations

from django.db import models


class ProductAffinity(models.Model):
    """
    Directed edge: from_product -> to_product
    Stored symmetrically (we write both directions) for fast lookups.
    """

    from_product = models.ForeignKey(
        'products.Product',
        on_delete=models.CASCADE,
        related_name='affinities_from',
    )
    to_product = models.ForeignKey(
        'products.Product',
        on_delete=models.CASCADE,
        related_name='affinities_to',
    )
    score = models.FloatField(default=0.0)
    last_updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['from_product', 'to_product'],
                name='uniq_product_affinity_edge',
            )
        ]
        indexes = [
            models.Index(fields=['from_product', '-score'], name='pa_from_score_idx'),
        ]

    def __str__(self) -> str:
        return f'{self.from_product_id}->{self.to_product_id} ({self.score})'


class Collection(models.Model):
    slug = models.SlugField(max_length=120, unique=True)
    title = models.CharField(max_length=200)
    subtitle = models.CharField(max_length=255, blank=True, default='')
    banner_image = models.ImageField(upload_to='collections/', blank=True, null=True)

    priority = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)

    targeting = models.JSONField(default=dict, blank=True)

    products = models.ManyToManyField(
        'products.Product',
        through='CollectionItem',
        related_name='collections',
        blank=True,
    )

    class Meta:
        indexes = [
            models.Index(fields=['is_active', 'starts_at', 'ends_at'], name='col_active_window_idx'),
            models.Index(fields=['-priority'], name='col_priority_idx'),
        ]

    def __str__(self) -> str:
        return self.title


class CollectionItem(models.Model):
    collection = models.ForeignKey(Collection, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey('products.Product', on_delete=models.CASCADE)
    sort_order = models.IntegerField(default=0)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['collection', 'product'],
                name='uniq_collection_product',
            )
        ]
        indexes = [
            models.Index(fields=['collection', 'sort_order'], name='colitem_order_idx'),
        ]

    def __str__(self) -> str:
        return f'{self.collection.slug}: {self.product_id}'
