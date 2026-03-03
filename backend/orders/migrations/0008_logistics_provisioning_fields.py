from django.db import migrations, models
import django.db.models.deletion
import django.db.models


def map_courier_webhook_source(apps, schema_editor):
    ShipmentEvent = apps.get_model('orders', 'ShipmentEvent')
    ShipmentEvent.objects.filter(source='COURIER_WEBHOOK').update(source='WEBHOOK')


class Migration(migrations.Migration):
    dependencies = [
        ('orders', '0007_order_bank_tran_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='suborder',
            name='provision_status',
            field=models.CharField(
                choices=[
                    ('NOT_STARTED', 'Not started'),
                    ('REQUESTED', 'Requested'),
                    ('CREATED', 'Created'),
                    ('FAILED', 'Failed'),
                ],
                default='NOT_STARTED',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='suborder',
            name='courier_reference_id',
            field=models.CharField(blank=True, default='', max_length=255),
        ),
        migrations.AddField(
            model_name='suborder',
            name='last_error',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='suborder',
            name='provision_request',
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AlterField(
            model_name='shipmentevent',
            name='source',
            field=models.CharField(
                choices=[
                    ('VENDOR', 'Vendor'),
                    ('WEBHOOK', 'Webhook'),
                    ('POLLING', 'Polling'),
                    ('SYSTEM', 'System'),
                ],
                default='VENDOR',
                max_length=20,
            ),
        ),
        migrations.AlterField(
            model_name='shipmentevent',
            name='external_event_id',
            field=models.CharField(
                blank=True,
                help_text='Idempotency key for courier webhooks',
                max_length=255,
                null=True,
            ),
        ),
        migrations.AddConstraint(
            model_name='shipmentevent',
            constraint=models.UniqueConstraint(
                condition=django.db.models.Q(external_event_id__isnull=False),
                fields=('sub_order', 'external_event_id'),
                name='uniq_shipmentevent_suborder_external_event_id',
            ),
        ),
        migrations.RunPython(
            code=map_courier_webhook_source,
            reverse_code=migrations.RunPython.noop,
        ),
    ]
