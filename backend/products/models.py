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
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

    @property
    def in_stock(self):
        return self.stock_quantity > 0
