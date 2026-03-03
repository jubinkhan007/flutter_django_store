from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ('vendors', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='CourierIntegration',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('courier', models.CharField(choices=[('REDX', 'RedX'), ('STEADFAST', 'Steadfast'), ('PATHAO', 'Pathao')], max_length=30)),
                ('owner_type', models.CharField(choices=[('PLATFORM', 'Platform'), ('VENDOR', 'Vendor')], default='PLATFORM', max_length=20)),
                ('mode', models.CharField(choices=[('SANDBOX', 'Sandbox'), ('PROD', 'Production')], default='SANDBOX', max_length=20)),
                ('is_enabled', models.BooleanField(default=False)),
                ('access_token', models.TextField(blank=True, default='')),
                ('refresh_token', models.TextField(blank=True, default='')),
                ('expires_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('owner_vendor', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, to='vendors.vendor')),
            ],
            options={
                'indexes': [models.Index(fields=['courier', 'owner_type', 'mode'], name='logistics_courier_2da0ef_idx')],
            },
        ),
        migrations.CreateModel(
            name='LogisticsStore',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('courier', models.CharField(choices=[('REDX', 'RedX'), ('STEADFAST', 'Steadfast'), ('PATHAO', 'Pathao')], max_length=30)),
                ('mode', models.CharField(choices=[('SANDBOX', 'Sandbox'), ('PROD', 'Production')], default='SANDBOX', max_length=20)),
                ('owner_type', models.CharField(choices=[('PLATFORM', 'Platform'), ('VENDOR', 'Vendor')], default='PLATFORM', max_length=20)),
                ('name', models.CharField(max_length=255)),
                ('contact_name', models.CharField(blank=True, default='', max_length=255)),
                ('phone', models.CharField(blank=True, default='', max_length=50)),
                ('address', models.TextField(blank=True, default='')),
                ('city', models.CharField(blank=True, default='', max_length=120)),
                ('area', models.CharField(blank=True, default='', max_length=120)),
                ('external_store_id', models.CharField(blank=True, default='', max_length=255)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('assigned_vendors', models.ManyToManyField(blank=True, related_name='logistics_stores', to='vendors.vendor')),
                ('owner_vendor', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, to='vendors.vendor')),
            ],
            options={
                'indexes': [models.Index(fields=['courier', 'mode', 'is_active'], name='logistics_courier_403bb4_idx')],
            },
        ),
        migrations.CreateModel(
            name='LogisticsArea',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('courier', models.CharField(choices=[('REDX', 'RedX'), ('STEADFAST', 'Steadfast'), ('PATHAO', 'Pathao')], max_length=30)),
                ('mode', models.CharField(choices=[('SANDBOX', 'Sandbox'), ('PROD', 'Production')], default='SANDBOX', max_length=20)),
                ('kind', models.CharField(choices=[('CITY', 'City'), ('ZONE', 'Zone'), ('AREA', 'Area')], max_length=20)),
                ('external_id', models.CharField(max_length=255)),
                ('name', models.CharField(max_length=255)),
                ('raw', models.JSONField(blank=True, default=dict)),
                ('last_synced_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('parent', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='children', to='logistics.logisticsarea')),
            ],
            options={
                'indexes': [
                    models.Index(fields=['courier', 'mode', 'kind', 'external_id'], name='logistics_courier_1e2d7b_idx'),
                    models.Index(fields=['courier', 'mode', 'kind', 'name'], name='logistics_courier_8ed8a8_idx'),
                ],
            },
        ),
        migrations.AddConstraint(
            model_name='courierintegration',
            constraint=models.UniqueConstraint(fields=('courier', 'owner_type', 'owner_vendor', 'mode'), name='uniq_courier_integration_owner_mode'),
        ),
        migrations.AddConstraint(
            model_name='logisticsarea',
            constraint=models.UniqueConstraint(fields=('courier', 'mode', 'kind', 'external_id'), name='uniq_logistics_area_key'),
        ),
    ]

