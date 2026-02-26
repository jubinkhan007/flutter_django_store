import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from datetime import timedelta
from django.utils import timezone
from promotions.models import Banner, FlashSale, FlashSaleProduct, FeaturedSection
from products.models import Product

def seed():
    now = timezone.now()
    
    # 1. Banners
    Banner.objects.all().delete()
    Banner.objects.create(
        title="Spring Cleaning Sale",
        subtitle="Up to 50% off home essentials",
        image_url="https://images.unsplash.com/photo-1584622650111-993a426fbf0a",
        link_type="CATEGORY",
        link_value="1",
        sort_order=1,
        is_active=True,
        starts_at=now - timedelta(days=1),
        ends_at=now + timedelta(days=7),
    )
    Banner.objects.create(
        title="Check out our new Arrivals!",
        subtitle="The latest styles for the season",
        image_url="https://images.unsplash.com/photo-1441984904996-e0b6ba687e04",
        link_type="URL",
        link_value="https://example.com/new",
        sort_order=2,
        is_active=True,
        starts_at=now - timedelta(days=1),
        ends_at=now + timedelta(days=7),
    )

    p1, _ = Product.objects.get_or_create(name="Smartphone", defaults={'price': 699.00, 'stock_quantity': 50})
    p2, _ = Product.objects.get_or_create(name="Laptop", defaults={'price': 1200.00, 'stock_quantity': 20})
    p3, _ = Product.objects.get_or_create(name="Headphones", defaults={'price': 150.00, 'stock_quantity': 100})
    p4, _ = Product.objects.get_or_create(name="Coffee Maker", defaults={'price': 80.00, 'stock_quantity': 30})

    # 2. Flash Sale
    FlashSale.objects.all().delete()
    fs = FlashSale.objects.create(
        title="Midnight Tech Deals",
        description="Grab the best electronics at deep discounts",
        is_active=True,
        starts_at=now - timedelta(hours=1),
        ends_at=now + timedelta(hours=5),
    )
    FlashSaleProduct.objects.create(
        flash_sale=fs,
        product=p1,
        discount_type='PERCENT',
        discount_value=20.00,  # 20% off
    )
    FlashSaleProduct.objects.create(
        flash_sale=fs,
        product=p3,
        discount_type='FIXED',
        discount_value=30.00,  # $30 off
    )

    # 3. Featured Rows
    FeaturedSection.objects.all().delete()
    trending = FeaturedSection.objects.create(
        title="Trending Right Now",
        section_type="TRENDING",
        is_active=True,
        sort_order=1,
        starts_at=now - timedelta(days=1),
        ends_at=now + timedelta(days=7),
    )
    trending.products.add(p1, p2)

    new_arrivals = FeaturedSection.objects.create(
        title="Fresh Styles",
        section_type="NEW_ARRIVALS",
        is_active=True,
        sort_order=2,
        starts_at=now - timedelta(days=1),
        ends_at=now + timedelta(days=7),
    )
    new_arrivals.products.add(p3, p4)

    print("Successfully seeded promotions!")

if __name__ == '__main__':
    seed()
