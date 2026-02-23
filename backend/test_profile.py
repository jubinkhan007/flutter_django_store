import os, django
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
