import random
from io import BytesIO
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.core.files.base import ContentFile
from django.contrib.auth import get_user_model
from faker import Faker
from PIL import Image, ImageDraw

from vendors.models import Vendor
from products.models import Category, Product, ProductVariant

User = get_user_model()
fake = Faker()

def create_placeholder_image(text, bg_color):
    """Generates an elegant colored image with centered text using Pillow."""
    img = Image.new('RGB', (800, 800), color=bg_color)
    d = ImageDraw.Draw(img)
    
    # We won't use custom fonts to avoid dependency issues.
    # Just draw a simple placeholder or return the solid color if text drawing looks bad without a font size.
    # The solid color alone looks premium enough for a demo if we use nice colors.
    
    # Let's add a subtle logo/circle in the middle
    circle_color = tuple(max(0, c - 20) for c in bg_color)
    d.ellipse([(200, 200), (600, 600)], fill=circle_color)
    
    buffer = BytesIO()
    img.save(buffer, format='JPEG', quality=85)
    return ContentFile(buffer.getvalue(), name=f"{text.lower().replace(' ', '_')}.jpg")


class Command(BaseCommand):
    help = 'Seeds the database with beautiful demo data for CodeCanyon previews.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.WARNING("Clearing old demo data..."))
        Product.objects.all().delete()
        Category.objects.all().delete()
        Vendor.objects.all().delete()
        User.objects.filter(is_superuser=False).delete()

        # 1. Categories
        self.stdout.write("Creating Categories...")
        categories_data = [
            ("Electronics", "#0f172a"),
            ("Fashion", "#f43f5e"),
            ("Home & Living", "#10b981"),
            ("Beauty", "#8b5cf6"),
            ("Tech Gadgets", "#3b82f6"),
        ]
        
        category_objs = []
        for name, color in categories_data:
            cat = Category.objects.create(
                name=name,
                slug=name.lower().replace(' ', '-').replace('&', 'and'),
                description=fake.sentence()
            )
            # Create a hex -> rgb tuple
            r = int(color[1:3], 16)
            g = int(color[3:5], 16)
            b = int(color[5:7], 16)
            cat.image.save(f"{cat.slug}.jpg", create_placeholder_image(name, (r, g, b)))
            category_objs.append(cat)

        # 2. Vendors
        self.stdout.write("Creating Vendors...")
        vendors = []
        for i in range(3):
            user = User.objects.create_user(
                username=f'vendor{i+1}',
                email=f'vendor{i+1}@demo.com',
                password='password123',
                first_name=fake.first_name(),
                last_name=fake.last_name(),
                role='VENDOR'
            )
            vendor = Vendor.objects.create(
                user=user,
                store_name=f"{fake.company()} Official",
                store_description=fake.catch_phrase(),
                support_email=user.email,
                phone_number=fake.phone_number()[:15],
                is_approved=True,
                status='ACTIVE'
            )
            vendors.append(vendor)

        # 3. Products
        self.stdout.write("Creating 50+ Products...")
        products_data = [
            ("Wireless Noise-Canceling Headphones", "Electronics", 199.99),
            ("Minimalist Cotton T-Shirt", "Fashion", 24.99),
            ("Ceramic Coffee Mug Setup", "Home & Living", 14.50),
            ("Organic Vitamin C Serum", "Beauty", 35.00),
            ("Mechanical RGB Keyboard", "Tech Gadgets", 120.00),
            ("Smart Fitness Watch", "Electronics", 299.00),
            ("Leather Crossbody Bag", "Fashion", 89.50),
            ("Ergonomic Office Chair", "Home & Living", 150.00),
            ("Hydrating Face Moisturizer", "Beauty", 22.00),
            ("4K Drone with HD Camera", "Tech Gadgets", 450.00),
        ] * 6  # Multiply by 6 to get 60 items

        # Create products
        colors = [
            (220, 38, 38), (234, 88, 12), (217, 119, 6), (101, 163, 13), 
            (16, 185, 129), (14, 165, 233), (59, 130, 246), (99, 102, 241), 
            (168, 85, 247), (236, 72, 153), (244, 63, 94)
        ]

        count = 0
        for name, cat_name, price in products_data:
            cat = next(c for c in category_objs if c.name == cat_name)
            vendor = random.choice(vendors)
            
            # Make names slightly unique
            count += 1
            unique_name = f"{name} {fake.color_name().title()} Ed. {count}"
            
            p = Product.objects.create(
                vendor=vendor,
                category=cat,
                name=unique_name,
                description=fake.paragraph(nb_sentences=5),
                price=Decimal(str(price)),
                stock_quantity=random.randint(10, 100),
                is_available=True,
                avg_rating=Decimal(str(round(random.uniform(3.5, 5.0), 1))),
                review_count=random.randint(5, 500)
            )
            
            bg_color = random.choice(colors)
            p.image.save(f"prod_{count}.jpg", create_placeholder_image("Product", bg_color))
            
            # Create a default variant so it can be added to cart
            ProductVariant.objects.create(
                product=p,
                sku=f"SKU-{count:05d}",
                price_override=None,
                stock_on_hand=p.stock_quantity,
                is_active=True
            )

        # 4. Dummy Users
        self.stdout.write("Creating Customers...")
        for i in range(5):
            User.objects.create_user(
                username=f'customer{i+1}',
                email=f'customer{i+1}@demo.com',
                password='password123',
                first_name=fake.first_name(),
                last_name=fake.last_name(),
                role='CUSTOMER'
            )

        self.stdout.write(self.style.SUCCESS("Demo Data Seeded Successfully! 🚀"))
        self.stdout.write(self.style.SUCCESS("You can now preview your beautiful store!"))
