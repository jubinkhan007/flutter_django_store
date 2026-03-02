from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('support', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='ticket',
            name='category',
            field=models.CharField(
                choices=[
                    ('ORDER', 'Order'),
                    ('PAYMENT', 'Payment'),
                    ('ACCOUNT', 'Account'),
                    ('TECH', 'Tech'),
                    ('OTHER', 'Other'),
                ],
                default='OTHER',
                max_length=30,
            ),
        ),
    ]

