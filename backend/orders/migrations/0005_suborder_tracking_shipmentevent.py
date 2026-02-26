from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0004_add_idempotency_key'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='suborder',
            name='courier_code',
            field=models.CharField(blank=True, help_text="e.g. 'pathao', 'redx'", max_length=50),
        ),
        migrations.AddField(
            model_name='suborder',
            name='courier_name',
            field=models.CharField(blank=True, help_text="e.g. 'Pathao Delivers'", max_length=100),
        ),
        migrations.AddField(
            model_name='suborder',
            name='tracking_number',
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AddField(
            model_name='suborder',
            name='tracking_url',
            field=models.URLField(blank=True),
        ),
        migrations.CreateModel(
            name='ShipmentEvent',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('status', models.CharField(
                    choices=[
                        ('PROCESSING', 'Processing'), ('PACKED', 'Packed'),
                        ('PICKED_UP', 'Picked Up'), ('IN_TRANSIT', 'In Transit'),
                        ('OUT_FOR_DELIVERY', 'Out for Delivery'), ('DELIVERED', 'Delivered'),
                        ('CANCELLED', 'Cancelled'), ('RETURNED', 'Returned'),
                    ],
                    max_length=30,
                )),
                ('location', models.CharField(blank=True, max_length=255)),
                ('timestamp', models.DateTimeField()),
                ('description', models.TextField(blank=True)),
                ('sequence', models.IntegerField(default=0)),
                ('source', models.CharField(
                    choices=[('VENDOR', 'Vendor'), ('COURIER_WEBHOOK', 'Courier Webhook'), ('SYSTEM', 'System')],
                    default='VENDOR', max_length=20,
                )),
                ('external_event_id', models.CharField(blank=True, max_length=255, null=True, unique=True)),
                ('sub_order', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='events', to='orders.suborder',
                )),
                ('created_by', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='shipment_events', to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={'ordering': ['sequence', 'timestamp']},
        ),
    ]
