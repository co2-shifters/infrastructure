from django.db import models

class Input(models.Model):
    input1 = models.DateTimeField()
    input2 = models.CharField(max_length=100)
    input3 = models.CharField(max_length=100)