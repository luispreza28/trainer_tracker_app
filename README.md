# TrainerTracker Backend

## Setup

1. Copy `.env.example` to `.env` and fill in your FDC_API_KEY.
2. Build and run with Docker Compose:
   ```sh
   docker-compose up --build
   ```
3. The API will be available at http://localhost:8000/api/

## Endpoints

- `GET /api/foods/search?q=apple` – Search foods (USDA FDC)
- `GET /api/foods/fdc/<fdc_id>` – Get food details by FDC ID
- `GET /api/foods/barcode/<code>` – Lookup food by barcode (Open Food Facts)
- `GET/POST /api/meals/` – List or create meal entries

## Example curl requests

```sh
# Search foods
curl 'http://localhost:8000/api/foods/search?q=apple' -H 'Authorization: Token <your_token>'

# Get FDC food details
curl 'http://localhost:8000/api/foods/fdc/123456' -H 'Authorization: Token <your_token>'

# Lookup by barcode
curl 'http://localhost:8000/api/foods/barcode/1234567890123' -H 'Authorization: Token <your_token>'

# List meals
curl 'http://localhost:8000/api/meals/' -H 'Authorization: Token <your_token>'

# Create meal entry
curl -X POST 'http://localhost:8000/api/meals/' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Token <your_token>' \
  -d '{"food": 1, "quantity": 100, "meal_time": "2023-01-01T12:00:00Z"}'
```
