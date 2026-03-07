from __future__ import annotations

from decimal import Decimal

from django.core.management.base import BaseCommand

from crossborder.models import CrossBorderCostConfig, CrossBorderProduct


class Command(BaseCommand):
    help = "Seed a small cross-border catalog (for dev/demo)."

    def add_arguments(self, parser):
        parser.add_argument("--count", type=int, default=8, help="Number of products to create.")
        parser.add_argument(
            "--force",
            action="store_true",
            help="Seed even if products already exist (otherwise no-op).",
        )

    def handle(self, *args, **options):
        count: int = options["count"]
        force: bool = options["force"]

        existing = CrossBorderProduct.objects.count()
        if existing and not force:
            self.stdout.write(self.style.WARNING(f"CrossBorderProduct already has {existing} rows; skipping."))
            self.stdout.write(self.style.WARNING("Run with `--force` to add more."))
            return

        templates = [
            {
                "title": "Wireless Noise-Cancelling Headphones",
                "origin_marketplace": CrossBorderProduct.Marketplace.AMAZON,
                "currency": "USD",
                "base_price_foreign": Decimal("79.99"),
                "estimated_weight_kg": Decimal("0.60"),
                "lead_time_days_min": 10,
                "lead_time_days_max": 18,
            },
            {
                "title": "Stainless Steel Water Bottle (1L)",
                "origin_marketplace": CrossBorderProduct.Marketplace.ALIEXPRESS,
                "currency": "USD",
                "base_price_foreign": Decimal("12.50"),
                "estimated_weight_kg": Decimal("0.45"),
                "lead_time_days_min": 12,
                "lead_time_days_max": 22,
            },
            {
                "title": "Mechanical Keyboard (Hot-swappable)",
                "origin_marketplace": CrossBorderProduct.Marketplace.AMAZON,
                "currency": "USD",
                "base_price_foreign": Decimal("54.00"),
                "estimated_weight_kg": Decimal("1.20"),
                "lead_time_days_min": 9,
                "lead_time_days_max": 16,
            },
            {
                "title": "Skincare Serum (Vitamin C 30ml)",
                "origin_marketplace": CrossBorderProduct.Marketplace.ALIEXPRESS,
                "currency": "USD",
                "base_price_foreign": Decimal("9.99"),
                "estimated_weight_kg": Decimal("0.20"),
                "lead_time_days_min": 14,
                "lead_time_days_max": 24,
            },
            {
                "title": "Smart LED Strip Lights (5m)",
                "origin_marketplace": CrossBorderProduct.Marketplace.ALIBABA,
                "currency": "USD",
                "base_price_foreign": Decimal("18.75"),
                "estimated_weight_kg": Decimal("0.35"),
                "lead_time_days_min": 10,
                "lead_time_days_max": 20,
            },
            {
                "title": "Portable SSD (1TB)",
                "origin_marketplace": CrossBorderProduct.Marketplace.AMAZON,
                "currency": "USD",
                "base_price_foreign": Decimal("69.00"),
                "estimated_weight_kg": Decimal("0.15"),
                "lead_time_days_min": 8,
                "lead_time_days_max": 15,
            },
            {
                "title": "Running Shoes (Lightweight)",
                "origin_marketplace": CrossBorderProduct.Marketplace.OTHER,
                "currency": "USD",
                "base_price_foreign": Decimal("44.99"),
                "estimated_weight_kg": Decimal("0.90"),
                "lead_time_days_min": 10,
                "lead_time_days_max": 21,
            },
            {
                "title": "Travel Backpack (30L)",
                "origin_marketplace": CrossBorderProduct.Marketplace.SHOP_1688,
                "currency": "USD",
                "base_price_foreign": Decimal("24.00"),
                "estimated_weight_kg": Decimal("0.80"),
                "lead_time_days_min": 12,
                "lead_time_days_max": 23,
            },
        ]

        created = 0
        for i in range(count):
            t = templates[i % len(templates)]
            CrossBorderProduct.objects.create(
                title=f"{t['title']} #{i + 1}",
                description="Seed item for Shop Abroad catalog (dev/demo).",
                images=[],
                origin_marketplace=t["origin_marketplace"],
                source_url="https://example.com/",
                supplier_sku=f"SEED-{i + 1:04d}",
                base_price_foreign=t["base_price_foreign"],
                currency=t["currency"],
                estimated_weight_kg=t["estimated_weight_kg"],
                is_active=True,
                priority=max(0, count - i),
                policy_summary="Returns/warranty may be limited for cross-border items.",
                lead_time_days_min=t["lead_time_days_min"],
                lead_time_days_max=t["lead_time_days_max"],
            )
            created += 1

        # Optional: seed cost configs if missing (quote service also has defaults).
        CrossBorderCostConfig.objects.get_or_create(
            shipping_method=CrossBorderCostConfig.ShippingMethod.AIR,
            defaults={
                "rate_per_kg": Decimal("500.00"),
                "service_fee_type": CrossBorderCostConfig.ServiceFeeType.PERCENTAGE,
                "service_fee_value": Decimal("10.00"),
                "customs_rate_percentage": Decimal("25.00"),
                "fx_rate_bdt": Decimal("110.00"),
                "is_active": True,
            },
        )
        CrossBorderCostConfig.objects.get_or_create(
            shipping_method=CrossBorderCostConfig.ShippingMethod.SEA,
            defaults={
                "rate_per_kg": Decimal("150.00"),
                "service_fee_type": CrossBorderCostConfig.ServiceFeeType.PERCENTAGE,
                "service_fee_value": Decimal("10.00"),
                "customs_rate_percentage": Decimal("25.00"),
                "fx_rate_bdt": Decimal("110.00"),
                "is_active": True,
            },
        )

        self.stdout.write(self.style.SUCCESS(f"Seeded {created} cross-border products."))

