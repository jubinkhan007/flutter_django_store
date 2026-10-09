from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("orders", "0009_merge_0008_logistics_provisioning_fields_0008_suborder_fulfillment_type_cb_shipment_events"),
    ]

    operations = [
        migrations.AddField(
            model_name="order",
            name="wallet_amount_applied",
            field=models.DecimalField(
                decimal_places=2,
                default=0.0,
                help_text="Amount deducted from customer wallet balance",
                max_digits=10,
            ),
        ),
        migrations.AlterField(
            model_name="order",
            name="payment_method",
            field=models.CharField(
                choices=[("ONLINE", "Online"), ("COD", "Cash on Delivery"), ("WALLET", "Wallet")],
                default="ONLINE",
                max_length=20,
            ),
        ),
    ]
