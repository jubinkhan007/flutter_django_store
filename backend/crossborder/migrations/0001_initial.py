import uuid
import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('orders', '0008_suborder_fulfillment_type_cb_shipment_events'),
        ('products', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='CrossBorderProduct',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=512)),
                ('description', models.TextField(blank=True)),
                ('images', models.JSONField(blank=True, default=list, help_text='List of image URLs')),
                ('origin_marketplace', models.CharField(choices=[('AMAZON', 'Amazon'), ('ALIEXPRESS', 'AliExpress'), ('ALIBABA', 'Alibaba'), ('1688', '1688'), ('OTHER', 'Other')], max_length=20)),
                ('source_url', models.URLField(max_length=1000)),
                ('supplier_sku', models.CharField(blank=True, max_length=255)),
                ('base_price_foreign', models.DecimalField(decimal_places=2, max_digits=14)),
                ('currency', models.CharField(default='USD', help_text='ISO 4217 currency code', max_length=3)),
                ('estimated_weight_kg', models.DecimalField(decimal_places=3, default=0.5, max_digits=8)),
                ('is_active', models.BooleanField(default=True)),
                ('priority', models.PositiveIntegerField(default=0, help_text='Higher = shown first')),
                ('policy_summary', models.TextField(blank=True, help_text='Return/warranty limitations')),
                ('lead_time_days_min', models.PositiveIntegerField(default=7)),
                ('lead_time_days_max', models.PositiveIntegerField(default=21)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('category', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='cb_products', to='products.category')),
            ],
            options={'ordering': ['-priority', '-created_at']},
        ),
        migrations.CreateModel(
            name='CrossBorderCostConfig',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('shipping_method', models.CharField(choices=[('AIR', 'Air Freight'), ('SEA', 'Sea Freight')], max_length=10, unique=True)),
                ('rate_per_kg', models.DecimalField(decimal_places=2, help_text='BDT per kg', max_digits=10)),
                ('service_fee_type', models.CharField(choices=[('FIXED', 'Fixed Amount (BDT)'), ('PERCENTAGE', 'Percentage of item price')], default='PERCENTAGE', max_length=20)),
                ('service_fee_value', models.DecimalField(decimal_places=2, default=10, help_text='Amount or %', max_digits=10)),
                ('customs_rate_percentage', models.DecimalField(decimal_places=2, default=25, help_text='Informational estimate only; customer pays on delivery', max_digits=5)),
                ('fx_rate_bdt', models.DecimalField(decimal_places=4, default=110, help_text='1 USD = X BDT', max_digits=10)),
                ('is_active', models.BooleanField(default=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
        ),
        migrations.CreateModel(
            name='CrossBorderOrderRequest',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('request_type', models.CharField(choices=[('CATALOG_ITEM', 'Catalog Item'), ('LINK_PURCHASE', 'Buy by Link')], max_length=20)),
                ('source_url', models.URLField(blank=True, max_length=1000)),
                ('marketplace', models.CharField(choices=[('AMAZON', 'Amazon'), ('ALIEXPRESS', 'AliExpress'), ('ALIBABA', 'Alibaba'), ('1688', '1688'), ('OTHER', 'Other')], default='OTHER', max_length=20)),
                ('variant_notes', models.TextField(blank=True, help_text='Color/size/spec the customer wants')),
                ('quantity', models.PositiveIntegerField(default=1)),
                ('delivery_mode', models.CharField(default='DIRECT_TO_CUSTOMER', editable=False, max_length=30)),
                ('customer_address_snapshot', models.JSONField(help_text='Exact address at checkout')),
                ('shipping_method', models.CharField(choices=[('AIR', 'Air Freight'), ('SEA', 'Sea Freight')], default='AIR', max_length=10)),
                ('quote_id', models.UUIDField(default=uuid.uuid4, unique=True)),
                ('quote_expires_at', models.DateTimeField(blank=True, null=True)),
                ('estimated_cost_breakdown', models.JSONField(blank=True, default=dict)),
                ('customs_policy_acknowledged', models.BooleanField(default=False)),
                ('expected_delivery_days_min', models.PositiveIntegerField(default=7)),
                ('expected_delivery_days_max', models.PositiveIntegerField(default=21)),
                ('status', models.CharField(choices=[('REQUESTED', 'Requested'), ('QUOTED', 'Quoted'), ('PAYMENT_RECEIVED', 'Payment Received'), ('ORDERED', 'Ordered from Supplier'), ('SHIPPED_INTL', 'Shipped Internationally'), ('IN_TRANSIT', 'In Transit (Local)'), ('OUT_FOR_DELIVERY', 'Out for Delivery'), ('DELIVERED', 'Delivered'), ('CANCELLED', 'Cancelled'), ('REFUND_IN_PROGRESS', 'Refund in Progress'), ('CUSTOMS_HELD', 'Held at Customs')], default='REQUESTED', max_length=30)),
                ('supplier_order_id', models.CharField(blank=True, max_length=255)),
                ('carrier_name', models.CharField(blank=True, max_length=100)),
                ('tracking_number', models.CharField(blank=True, max_length=255)),
                ('tracking_url', models.URLField(blank=True)),
                ('realized_item_cost_bdt', models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True)),
                ('realized_shipping_bdt', models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True)),
                ('ops_notes', models.TextField(blank=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('quoted_at', models.DateTimeField(blank=True, null=True)),
                ('ordered_at', models.DateTimeField(blank=True, null=True)),
                ('shipped_intl_at', models.DateTimeField(blank=True, null=True)),
                ('delivered_at', models.DateTimeField(blank=True, null=True)),
                ('assigned_ops_user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='assigned_cb_requests', to=settings.AUTH_USER_MODEL)),
                ('crossborder_product', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='order_requests', to='crossborder.crossborderproduct')),
                ('customer', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='cb_requests', to=settings.AUTH_USER_MODEL)),
                ('sub_order', models.OneToOneField(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='cb_request', to='orders.suborder')),
            ],
            options={'ordering': ['-created_at']},
        ),
    ]
