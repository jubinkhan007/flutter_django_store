from django.core.management.base import BaseCommand

from returns.services import escalate_overdue_returns


class Command(BaseCommand):
    help = 'Escalate overdue return requests awaiting vendor response.'

    def handle(self, *args, **options):
        updated = escalate_overdue_returns()
        self.stdout.write(self.style.SUCCESS(f'Escalated {updated} return request(s).'))

