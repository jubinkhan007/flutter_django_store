import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from products.models import Category

from django.utils.text import slugify

def seed_categories():
    categories = [
        {'name': 'Electronics', 'description': 'Gadgets and electronic devices'},
        {'name': 'Clothing', 'description': 'Apparel and accessories'},
        {'name': 'Home & Garden', 'description': 'Furniture and home decor'},
        {'name': 'Sports', 'description': 'Sporting goods and equipment'},
        {'name': 'Books', 'description': 'Physical and digital books'},
    ]
    
    count = 0
    for cat_data in categories:
        slug = slugify(cat_data['name'])
        cat, created = Category.objects.get_or_create(
            name=cat_data['name'], 
            defaults={
                'description': cat_data['description'],
                'slug': slug
            }
        )
        if created:
            count += 1
            print(f"Created category: {cat.name}")
    
    print(f"Seeding complete. {count} categories created.")

if __name__ == '__main__':
    seed_categories()
