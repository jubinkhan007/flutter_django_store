"""
Utility script for debugging local vendor profile relationships.

Note: this file is intentionally safe to import so Django test discovery
doesn't fail (Django discovers modules named `test_*.py`).
"""

if __name__ == '__main__':
    import os

    import django

    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    django.setup()

    from users.models import User
    from vendors.models import Vendor

    user = User.objects.get(username='testvendorproducts')
    print(user, user.id)
    vendor = Vendor.objects.get(user=user)
    print(vendor, vendor.id)
    try:
        print(user.vendor_profile)
    except Exception as e:
        print("Error:", type(e), e)
