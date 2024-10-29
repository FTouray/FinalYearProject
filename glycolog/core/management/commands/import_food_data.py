import csv
from django.core.management.base import BaseCommand
from core.models import FoodItem, FoodCategory

class Command(BaseCommand):
    help = 'Imports food data from CSV into the database'

    def handle(self, *args, **kwargs):
        try:
            with open('GRTData\food_data.csv', 'r') as file:
                reader = csv.DictReader(file)
                for row in reader:
                    category_name = row['Category']
                    category, _ = FoodCategory.objects.get_or_create(name=category_name)

                    # Convert GI and Carbs to float
                    try:
                        gi = float(row['GI'])
                        carbs = float(row['Carbs'])
                    except ValueError:
                        self.stdout.write(self.style.ERROR(f"Invalid data in row: {row}"))
                        continue

                    FoodItem.objects.create(
                        name=row['Food Name'],
                        glycaemic_index=gi,
                        carbs=carbs,
                        category=category
                    )
            self.stdout.write(self.style.SUCCESS('Data imported successfully'))
        except FileNotFoundError:
            self.stdout.write(self.style.ERROR('CSV file not found'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"An error occurred: {e}"))