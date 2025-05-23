# Generated by Django 5.1.1 on 2024-11-10 00:43

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0002_customuser_meal_count_alter_customuser_first_name_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='GlucoseLog',
            fields=[
                ('logID', models.AutoField(primary_key=True, serialize=False)),
                ('glucose_level', models.FloatField()),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('meal_context', models.CharField(choices=[('fasting', 'Fasting'), ('pre_meal', 'Pre-Meal'), ('post_meal', 'Post-Meal')], max_length=50)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='glucose_logs', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'indexes': [models.Index(fields=['user'], name='core_glucos_user_id_8516be_idx')],
                'constraints': [models.CheckConstraint(condition=models.Q(('glucose_level__gte', 0)), name='glucose_level_gte_0')],
            },
        ),
    ]
