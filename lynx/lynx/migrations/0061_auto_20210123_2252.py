# Generated by Django 2.2.17 on 2021-01-24 06:52

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('lynx', '0060_auto_20210122_0846'),
    ]

    operations = [
        migrations.AddField(
            model_name='emergencycontact',
            name='relationship',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='historicalemergencycontact',
            name='relationship',
            field=models.TextField(blank=True, null=True),
        ),
    ]