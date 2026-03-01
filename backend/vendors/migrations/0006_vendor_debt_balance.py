from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('vendors', '0005_vendor_avg_rating_vendor_cover_image_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='vendor',
            name='debt_balance',
            field=models.DecimalField(decimal_places=2, default=0.0, max_digits=12),
        ),
    ]
