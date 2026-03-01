from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0006_alter_shipmentevent_external_event_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='bank_tran_id',
            field=models.CharField(
                blank=True,
                help_text='Bank-side transaction ID from SSLCommerz (required for refund API).',
                max_length=80,
                null=True,
            ),
        ),
    ]

