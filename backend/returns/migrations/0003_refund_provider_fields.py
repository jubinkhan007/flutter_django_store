from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('returns', '0002_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='refund',
            name='provider',
            field=models.CharField(blank=True, default='', max_length=30),
        ),
        migrations.AddField(
            model_name='refund',
            name='provider_ref_id',
            field=models.CharField(blank=True, default='', max_length=80),
        ),
        migrations.AddField(
            model_name='refund',
            name='provider_trans_id',
            field=models.CharField(blank=True, default='', max_length=30),
        ),
    ]

