from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db import models

class CustomUser(AbstractUser):
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    first_name = models.CharField(max_length=30, blank=False, null=False) 
    last_name = models.CharField(max_length=30, blank=False, null=False) 
