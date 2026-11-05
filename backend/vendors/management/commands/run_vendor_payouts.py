from django.core.management.base import BaseCommand
from vendors.disbursal_service import VendorDisbursalService
from vendors.models import PayoutRequest


class Command(BaseCommand):
    help = "Executes automated vendor payouts and scheduled disbursals via bKash / Nagad / Bank."

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Bypass schedule frequency checks and disburse for all eligible vendors meeting threshold.',
        )
        parser.add_argument(
            '--payout-id',
            type=int,
            help='Disburse a specific existing PayoutRequest by ID.',
        )

    def handle(self, *args, **options):
        payout_id = options.get('payout_id')
        force = options.get('force', False)

        if payout_id:
            self.stdout.write(f"Initiating single disbursal for PayoutRequest #{payout_id}...")
            try:
                payout = PayoutRequest.objects.get(id=payout_id)
                res = VendorDisbursalService.disburse_payout(payout)
                if res.get('success'):
                    self.stdout.write(self.style.SUCCESS(
                        f"Successfully disbursed Payout #{payout_id}: ৳{res['amount']} "
                        f"via {res['channel']} (Ref: {res['gateway_reference']})"
                    ))
                else:
                    self.stdout.write(self.style.ERROR(
                        f"Disbursal failed for Payout #{payout_id}: {res.get('error')}"
                    ))
            except PayoutRequest.DoesNotExist:
                self.stdout.write(self.style.ERROR(f"PayoutRequest #{payout_id} does not exist."))
            return

        self.stdout.write("Running scheduled automated vendor payouts runner...")
        res = VendorDisbursalService.process_scheduled_auto_payouts(force=force)

        self.stdout.write(self.style.SUCCESS(
            f"Automated Payouts Completed: Processed {res['processed_count']} payouts. "
            f"Total Disbursed: ৳{res['total_disbursed']:.2f}. "
            f"Skipped: {len(res['skipped'])}, Errors: {len(res['errors'])}"
        ))

        for p in res['payouts']:
            self.stdout.write(
                f"  - Payout #{p['payout_id']}: ৳{p['amount']:.2f} via {p['channel']} "
                f"[Ref: {p['gateway_reference']}]"
            )

        for err in res['errors']:
            self.stdout.write(self.style.WARNING(
                f"  - Vendor #{err.get('vendor_id')} Error: {err.get('error')}"
            ))
