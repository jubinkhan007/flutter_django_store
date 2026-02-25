# ═══════════════════════════════════════════════════════════════════
# PROMOTIONS MODELS
# Enterprise-grade promotional content for dynamic home feed
# ═══════════════════════════════════════════════════════════════════

from django.db import models
from django.utils import timezone
from products.models import Product


# ── Shared QuerySet ──────────────────────────────────────────────

class PromotionQuerySet(models.QuerySet):
    """Shared queryset for all promotional models."""

    def active(self, now=None):
        """Return only items that are active AND within their scheduled window."""
        now = now or timezone.now()
        return self.filter(
            is_active=True,
            starts_at__lte=now,
            ends_at__gte=now,
        )


class PromotionManager(models.Manager):
    def get_queryset(self):
        return PromotionQuerySet(self.model, using=self._db)

    def active(self, now=None):
        return self.get_queryset().active(now)


# ── Targeting Choices ────────────────────────────────────────────

class Audience(models.TextChoices):
    ALL = 'ALL', 'All Users'
    NEW_USERS = 'NEW', 'New Users'
    RETURNING = 'RETURNING', 'Returning Users'
    VIP = 'VIP', 'VIP Users'


class Platform(models.TextChoices):
    ALL = 'ALL', 'All Platforms'
    ANDROID = 'ANDROID', 'Android'
    IOS = 'IOS', 'iOS'


class Locale(models.TextChoices):
    EN = 'en', 'English'
    BN = 'bn', 'Bangla'


# ── Abstract Base ────────────────────────────────────────────────

class PromotionBase(models.Model):
    """
    Abstract base for all promotional content.
    Provides consistent scheduling, targeting, and ordering.
    """
    # Scheduling
    is_active = models.BooleanField(default=True, help_text="Master on/off switch.")
    priority = models.IntegerField(
        default=0,
        help_text="Higher priority items appear first. Use 0–100.",
    )
    starts_at = models.DateTimeField(help_text="When this promotion becomes visible.")
    ends_at = models.DateTimeField(help_text="When this promotion expires.")

    # Targeting
    audience = models.CharField(
        max_length=20,
        choices=Audience.choices,
        default=Audience.ALL,
        help_text="Which user segment should see this.",
    )
    platform = models.CharField(
        max_length=20,
        choices=Platform.choices,
        default=Platform.ALL,
        help_text="Which platform should display this.",
    )
    locale = models.CharField(
        max_length=5,
        choices=Locale.choices,
        default=Locale.EN,
        help_text="Language/locale targeting.",
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = PromotionManager()

    class Meta:
        abstract = True
        ordering = ['-priority', 'starts_at']

    @property
    def is_live(self):
        now = timezone.now()
        return self.is_active and self.starts_at <= now <= self.ends_at


# ═══════════════════════════════════════════════════════════════════
# BANNER MODEL
# ═══════════════════════════════════════════════════════════════════

class Banner(PromotionBase):
    """
    Hero carousel banner for the home screen.
    Images are uploaded via Django Admin.
    """
    class LinkType(models.TextChoices):
        PRODUCT = 'PRODUCT', 'Product Detail'
        CATEGORY = 'CATEGORY', 'Category Filter'
        URL = 'URL', 'External/Custom URL'
        SEARCH = 'SEARCH', 'Search Query'
        NONE = 'NONE', 'No Link'

    title = models.CharField(max_length=120, help_text="Headline text overlay.")
    subtitle = models.CharField(max_length=200, blank=True, help_text="Sub-headline text overlay.")
    image = models.ImageField(
        upload_to='promotions/banners/',
        help_text="Recommended: 1080×500px, JPEG/WebP, < 500KB.",
    )
    link_type = models.CharField(
        max_length=20,
        choices=LinkType.choices,
        default=LinkType.NONE,
        help_text="What tapping the banner opens.",
    )
    link_value = models.CharField(
        max_length=500,
        blank=True,
        help_text="Product ID, Category Slug, URL, or Search query depending on link_type.",
    )

    class Meta(PromotionBase.Meta):
        verbose_name = 'Banner'
        verbose_name_plural = 'Banners'

    def __str__(self):
        return f"Banner: {self.title}"


# ═══════════════════════════════════════════════════════════════════
# FLASH SALE MODEL
# ═══════════════════════════════════════════════════════════════════

class FlashSale(PromotionBase):
    """
    A time-limited sale event containing multiple discounted products.
    """
    title = models.CharField(max_length=120, help_text="e.g., 'Mega Monday Flash Sale'")
    description = models.TextField(blank=True)
    products = models.ManyToManyField(
        Product,
        through='FlashSaleProduct',
        related_name='flash_sales',
        blank=True,
    )

    class Meta(PromotionBase.Meta):
        verbose_name = 'Flash Sale'
        verbose_name_plural = 'Flash Sales'

    def __str__(self):
        return f"Flash Sale: {self.title}"


class FlashSaleProduct(models.Model):
    """
    Through-model linking a Product to a FlashSale with pricing and limits.
    """
    class DiscountType(models.TextChoices):
        PRICE = 'PRICE', 'Fixed Price'
        PERCENT = 'PERCENT', 'Percentage Off'

    flash_sale = models.ForeignKey(FlashSale, on_delete=models.CASCADE, related_name='sale_products')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='flash_sale_entries')

    discount_type = models.CharField(
        max_length=10,
        choices=DiscountType.choices,
        default=DiscountType.PRICE,
    )
    discount_value = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="If PRICE: the sale price. If PERCENT: the % off (e.g., 30 = 30% off).",
    )
    purchase_limit_total = models.PositiveIntegerField(
        null=True, blank=True,
        help_text="Max total units for this deal across all users. Null = unlimited.",
    )
    max_per_user = models.PositiveIntegerField(
        null=True, blank=True,
        help_text="Max units a single user can buy at this price. Null = unlimited.",
    )
    sort_order = models.IntegerField(
        default=0,
        help_text="Order within the flash sale. Lower = first.",
    )
    is_active = models.BooleanField(default=True, help_text="Disable individual items within a sale.")

    class Meta:
        ordering = ['sort_order']
        unique_together = ('flash_sale', 'product')

    def __str__(self):
        return f"{self.product.name} in {self.flash_sale.title}"

    @property
    def effective_sale_price(self):
        """Calculate effective sale price based on discount type."""
        if self.discount_type == self.DiscountType.PRICE:
            return self.discount_value
        else:
            # Percentage off
            original = self.product.price
            discount = original * (self.discount_value / 100)
            return max(original - discount, 0)


# ═══════════════════════════════════════════════════════════════════
# FEATURED SECTION MODEL
# ═══════════════════════════════════════════════════════════════════

class FeaturedSection(PromotionBase):
    """
    A curated or algorithmic product row on the home screen.
    """
    class SectionType(models.TextChoices):
        TRENDING = 'TRENDING', 'Trending 🔥'
        NEW_ARRIVALS = 'NEW_ARRIVALS', 'New Arrivals ✨'
        TOP_RATED = 'TOP_RATED', 'Top Rated ⭐'
        CURATED = 'CURATED', 'Hand-Picked by Admin'

    title = models.CharField(max_length=120, help_text="Section heading shown to users.")
    section_type = models.CharField(
        max_length=20,
        choices=SectionType.choices,
        default=SectionType.CURATED,
    )
    products = models.ManyToManyField(
        Product,
        related_name='featured_sections',
        blank=True,
        help_text="For CURATED type: select products manually. For others, products are fetched dynamically.",
    )

    class Meta(PromotionBase.Meta):
        verbose_name = 'Featured Section'
        verbose_name_plural = 'Featured Sections'

    def __str__(self):
        return f"Featured: {self.title} ({self.section_type})"
