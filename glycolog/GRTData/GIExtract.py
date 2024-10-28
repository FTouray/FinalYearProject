from bs4 import BeautifulSoup
import pandas as pd

# Step 1: Load the HTML file
with open('GI WebP.html', 'r', encoding='utf-8') as file:
    html_content = file.read()

# Step 2: Parse the HTML content using BeautifulSoup
soup = BeautifulSoup(html_content, 'html.parser')

# Step 3: Find the relevant tags containing the food data
# Locate the table with the food data
table = soup.find('table', {'id': 'tablepress-1'})

# Debugging: Check if the table is found
if table is None:
    print("Error: Table with ID 'tablepress-1' not found.")
    exit()

# Step 4: Extract the food name, category, GI, and carbs
data = []
for row in table.find_all('tr')[1:]:  # Skip the header row
    cols = row.find_all('td')
    if len(cols) < 8:
        print("Error: Row does not contain enough columns.")
        continue
    food_name = cols[0].text.strip()
    gi = float(cols[1].text.strip())
    category = cols[3].text.strip()
    
    # Handle empty carbs value
    carbs_text = cols[7].text.strip()
    if carbs_text:
        carbs = float(carbs_text)
    else:
        carbs = 0.0  # Set a default value or skip the row

    # Filter: Only include foods with GI >= 70
    if gi >= 70:
        data.append([food_name, category, gi, carbs])

# Step 5: Store the extracted data in a pandas DataFrame
df = pd.DataFrame(data, columns=['Food Name', 'Category', 'GI', 'Carbs'])

# Step 6: Save the DataFrame to a CSV file
df.to_csv('food_data.csv', index=False)

print("Data extracted and saved to food_data.csv")