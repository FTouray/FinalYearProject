import requests
from bs4 import BeautifulSoup
from django.core.management.base import BaseCommand
from core.models import FoodCategory, FoodItem  

class Command(BaseCommand):
    help = 'Fetch high GI foods from the website and save to the database'

    def handle(self, *args, **kwargs):
        # URL of the website to scrape
        url = 'https://glycemicindex.com/gi-search/'

        # Send a GET request to the website
        response = requests.get(url)
        response.raise_for_status()  # Check if the request was successful

        # Parse the HTML content using BeautifulSoup
        soup = BeautifulSoup(response.content, 'html.parser')

        # Find the table containing the GI data
        table = soup.find('table', {'id': 'tablepress-1'})

        # Extract the rows from the table
        rows = table.find_all('tr')[1:]  # Skip the header row

        # Iterate over the rows and extract data
        for row in rows:
            columns = row.find_all('td')
            food_name = columns[0].text.strip()
            gi_value = int(columns[1].text.strip())
            carbs = columns[7].text.strip()
            category_name = columns[3].text.strip()

            # Convert carbs to float, set to None if empty
            try:
                carbs = float(carbs) if carbs else None
            except ValueError:
                carbs = None

            # Check if the GI value is 70 or above
            if gi_value >= 70:
                # Get or create the food category
                category, created = FoodCategory.objects.get_or_create(name=category_name)

                # Create the food item
                FoodItem.objects.update_or_create(
                    name=food_name,
                    defaults={
                        'glycaemic_index': gi_value,
                        'carbs': carbs,
                        'category': category
                    }
                )

        self.stdout.write(self.style.SUCCESS('Successfully fetched and saved high GI foods'))
