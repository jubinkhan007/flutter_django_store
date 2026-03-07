from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0007_order_bank_tran_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='suborder',
            name='fulfillment_type',
            field=models.CharField(
                choices=[
                    ('LOCAL', 'Local'),
                    ('CROSS_BORDER_DIRECT', 'Cross-Border (Direct Import)'),
                ],
                default='LOCAL',
                max_length=30,
            ),
        ),
        migrations.AlterField(
            model_name='shipmentevent',
            name='status',
            field=models.CharField(
                choices=[
                    ('PROCESSING', 'Processing'),
                    ('PACKED', 'Packed'),
                    ('PICKED_UP', 'Picked Up'),
                    ('IN_TRANSIT', 'In Transit'),
                    ('OUT_FOR_DELIVERY', 'Out for Delivery'),
                    ('DELIVERED', 'Delivered'),
                    ('CANCELLED', 'Cancelled'),
                    ('RETURNED', 'Returned'),
                    ('ORDERED', 'Ordered from Supplier'),
                    ('SHIPPED_INTL', 'Shipped Internationally'),
                    ('CUSTOMS_HELD', 'Held at Customs'),
                ],
                max_length=30,
            ),
        ),
    ]
