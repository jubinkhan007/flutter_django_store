import json

from django.db import models
from django.utils import timezone
from django.utils.text import slugify

from .html_utils import sanitize_html


class TimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class SiteSetting(TimestampedModel):
    class SettingType(models.TextChoices):
        TEXT = 'TEXT', 'Text'
        URL = 'URL', 'URL'
        BOOLEAN = 'BOOLEAN', 'Boolean'
        IMAGE = 'IMAGE', 'Image'
        JSON = 'JSON', 'JSON'

    class Group(models.TextChoices):
        BRANDING = 'branding', 'Branding'
        CONTACT = 'contact', 'Contact'
        SOCIAL = 'social', 'Social'
        APP = 'app', 'App'
        MAINTENANCE = 'maintenance', 'Maintenance'

    key = models.SlugField(max_length=120, unique=True)
    value = models.TextField(blank=True, default='')
    image = models.ImageField(upload_to='cms/settings/', blank=True, null=True)
    setting_type = models.CharField(
        max_length=20,
        choices=SettingType.choices,
        default=SettingType.TEXT,
    )
    group = models.CharField(
        max_length=20,
        choices=Group.choices,
        default=Group.APP,
    )
    is_public = models.BooleanField(default=True)

    class Meta:
        ordering = ['group', 'key']

    def __str__(self):
        return self.key

    def clean(self):
        if self.setting_type == self.SettingType.JSON and self.value:
            json.loads(self.value)

    @property
    def typed_value(self):
        if self.setting_type == self.SettingType.BOOLEAN:
            return self.value.strip().lower() in {'1', 'true', 'yes', 'y', 'on'}
        if self.setting_type == self.SettingType.JSON:
            return json.loads(self.value or '{}')
        if self.setting_type == self.SettingType.IMAGE:
            if self.image:
                return self.image.url
            return self.value
        return self.value


class Page(TimestampedModel):
    class PageType(models.TextChoices):
        PRIVACY = 'PRIVACY', 'Privacy Policy'
        TERMS = 'TERMS', 'Terms & Conditions'
        ABOUT = 'ABOUT', 'About Us'
        REFUND_POLICY = 'REFUND_POLICY', 'Refund Policy'
        CUSTOM = 'CUSTOM', 'Custom'

    title = models.CharField(max_length=200)
    slug = models.SlugField(max_length=220, unique=True)
    page_type = models.CharField(
        max_length=30,
        choices=PageType.choices,
        default=PageType.CUSTOM,
    )
    content = models.TextField(blank=True, default='')
    meta_title = models.CharField(max_length=255, blank=True)
    meta_description = models.CharField(max_length=320, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['title']

    def __str__(self):
        return self.title

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.title)[:220]
        self.content = sanitize_html(self.content)
        super().save(*args, **kwargs)


class BannerQuerySet(models.QuerySet):
    def active(self, now=None):
        now = now or timezone.now()
        return self.filter(is_active=True).filter(
            models.Q(starts_at__isnull=True) | models.Q(starts_at__lte=now),
            models.Q(ends_at__isnull=True) | models.Q(ends_at__gte=now),
        )


class Banner(TimestampedModel):
    class TargetType(models.TextChoices):
        NONE = 'NONE', 'None'
        EXTERNAL_URL = 'EXTERNAL_URL', 'External URL'
        PRODUCT = 'PRODUCT', 'Product'
        CATEGORY = 'CATEGORY', 'Category'
        PAGE = 'PAGE', 'Page'

    class Platform(models.TextChoices):
        ALL = 'ALL', 'All'
        ANDROID = 'ANDROID', 'Android'
        IOS = 'IOS', 'iOS'

    class Position(models.TextChoices):
        HOME_TOP = 'HOME_TOP', 'Home Top'
        HOME_MID = 'HOME_MID', 'Home Mid'

    title = models.CharField(max_length=180)
    subtitle = models.CharField(max_length=255, blank=True)
    image = models.ImageField(upload_to='cms/banners/')
    target_type = models.CharField(
        max_length=20,
        choices=TargetType.choices,
        default=TargetType.NONE,
    )
    target_value = models.CharField(max_length=500, blank=True)
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    platform = models.CharField(
        max_length=20,
        choices=Platform.choices,
        default=Platform.ALL,
    )
    position = models.CharField(
        max_length=20,
        choices=Position.choices,
        default=Position.HOME_TOP,
    )

    objects = BannerQuerySet.as_manager()

    class Meta:
        ordering = ['position', 'display_order', '-updated_at']

    def __str__(self):
        return self.title


class FAQ(TimestampedModel):
    class Category(models.TextChoices):
        ORDERS = 'Orders', 'Orders'
        PAYMENTS = 'Payments', 'Payments'
        SHIPPING = 'Shipping', 'Shipping'
        RETURNS = 'Returns', 'Returns'
        ACCOUNT = 'Account', 'Account'

    category = models.CharField(max_length=30, choices=Category.choices)
    question = models.CharField(max_length=255)
    answer = models.TextField()
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['category', 'display_order', 'id']

    def __str__(self):
        return self.question

