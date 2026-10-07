from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('crossborder', '0002_alter_crossborderorderrequest_estimated_cost_breakdown'),
    ]

    operations = [
        migrations.AddField(
            model_name='crossborderorderrequest',
            name='item_title',
            field=models.CharField(blank=True, default='', help_text='Scraped/custom product title', max_length=512),
        ),
        migrations.AddField(
            model_name='crossborderorderrequest',
            name='item_image_url',
            field=models.URLField(blank=True, default='', help_text='Scraped product image', max_length=1000),
        ),
        migrations.AddField(
            model_name='crossborderorderrequest',
            name='item_description',
            field=models.TextField(blank=True, default=''),
        ),
    ]
