from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    class Types(models.TextChoices):
        CUSTOMER = "CUSTOMER", "Customer"
        VENDOR = "VENDOR", "Vendor"
        ADMIN = "ADMIN", "Admin"

    type = models.CharField(
        max_length=50, choices=Types.choices, default=Types.CUSTOMER
    )
    email = models.EmailField(unique=True)
    # Add other fields like avatar here if needed
    
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return self.email
