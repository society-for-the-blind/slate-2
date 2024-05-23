# Generated by Django 4.2 on 2024-04-18 15:19

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('lynx', '0091_auto_20240418_1505'),
    ]

    operations = [
        migrations.AddField(
            model_name='historicalassignment',
            name='program',
            field=models.CharField(choices=[('SIP', 'SIP'), ('1854', '1854')], default='', max_length=25),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='historicalsip1854assignment',
            name='program',
            field=models.CharField(choices=[('SIP', 'SIP'), ('1854', '1854')], default='', max_length=25),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name='assignment',
            name='program',
            field=models.CharField(choices=[('SIP', 'SIP'), ('1854', '1854')], max_length=25),
        ),
        migrations.AlterField(
            model_name='sip1854assignment',
            name='program',
            field=models.CharField(choices=[('SIP', 'SIP'), ('1854', '1854')], max_length=25),
        ),
    ]