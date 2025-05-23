# Generated by Django 5.1.1 on 2024-12-12 21:02

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0016_questionnairesession'),
    ]

    operations = [
        migrations.CreateModel(
            name='SymptomCheck',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('symptoms', models.JSONField()),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('session', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='symptom_check', to='core.questionnairesession')),
            ],
        ),
    ]
