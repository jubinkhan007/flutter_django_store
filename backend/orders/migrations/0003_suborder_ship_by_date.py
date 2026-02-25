from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0002_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='suborder',
            name='ship_by_date',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
