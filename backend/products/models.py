from django.db import models
from vendors.models import Vendor

class Category(models.Model):
    """
    Categories help organize products (e.g., Electronics, Clothing, Home & Garden).
    Categories are usually managed by the Admin, not individual vendors.
    """
    name = models.CharField(max_length=100)
    slug = models.SlugField(max_length=120, unique=True, help_text="A URL-friendly version of the name.")
    description = models.TextField(blank=True)
    image = models.ImageField(upload_to='categories/', blank=True, null=True)
    is_sealed = models.BooleanField(
        default=False,
        help_text="Sealed items may have stricter return rules (e.g., must be unopened).",
    )

    class Meta:
        verbose_name_plural = 'Categories'

    def __str__(self):
        return self.name


class Product(models.Model):
    """
    A single item being sold in the store by a specific Vendor.
    """
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='products')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name='products')
    
    name = models.CharField(max_length=200)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    stock_quantity = models.PositiveIntegerField(default=0)
    
    # Optional image. If a vendor doesn't upload one, we can display a default placeholder in Flutter.
    image = models.ImageField(upload_to='products/', blank=True, null=True)
    
    # Allows vendors to hide a product without deleting it
    is_available = models.BooleanField(default=True)
    
    # Denormalized Aggregates for Performance
    avg_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    review_count = models.PositiveIntegerField(default=0)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

    @property
    def in_stock(self):
        return self.stock_quantity > 0

class ProductOption(models.Model):
    """e.g., Size, Color"""
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='options')
    name = models.CharField(max_length=50)
    slug = models.SlugField(max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('product', 'name')

    def __str__(self):
        return f"{self.product.name} - {self.name}"

class ProductOptionValue(models.Model):
    """e.g., M, L, Red"""
    option = models.ForeignKey(ProductOption, on_delete=models.CASCADE, related_name='values')
    value = models.CharField(max_length=50)
    slug = models.SlugField(max_length=50, blank=True)

    class Meta:
        unique_together = ('option', 'value')

    def __str__(self):
        return self.value

class ProductVariant(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='variants')
    sku = models.CharField(max_length=100)
    option_values = models.ManyToManyField(ProductOptionValue, blank=True)
    
    price_override = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    currency = models.CharField(max_length=10, default='USD')
    
    stock_on_hand = models.PositiveIntegerField(default=0)
    reserved_stock = models.PositiveIntegerField(default=0)
    low_stock_threshold = models.PositiveIntegerField(default=5)
    
    barcode = models.CharField(max_length=100, blank=True, null=True)
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['product', 'sku'], name='unique_product_sku')
        ]

    def __str__(self):
        return f"{self.product.name} - {self.sku}"

    @property
    def effective_price(self):
        return self.price_override if self.price_override is not None else self.product.price

    @property
    def available_stock(self):
        return max(0, self.stock_on_hand - self.reserved_stock)

class Wishlist(models.Model):
    """
    A user's saved items for later purchase.
    """
    from django.conf import settings
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='wishlist_items')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='wishlisted_by')
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'product')
        ordering = ['-added_at']

    def __str__(self):
        return f"{self.user.email} - {self.product.name}"
