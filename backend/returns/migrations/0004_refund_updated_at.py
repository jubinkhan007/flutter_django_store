from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("returns", "0003_refund_provider_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="refund",
            name="updated_at",
            field=models.DateTimeField(auto_now=True),
        ),
    ]

