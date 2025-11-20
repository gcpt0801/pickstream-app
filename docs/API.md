# API Documentation

## Base URL

- **Development**: `http://localhost:8080/api`
- **Production**: `https://pickstream.example.com/api`

## Endpoints

### Get Random Name

Returns a randomly selected name from the available list.

**Endpoint**: `GET /api/random-name`

**Response**:
```json
{
  "name": "Alice",
  "timestamp": 1704067200000
}
```

**Example**:
```bash
curl http://localhost:8080/api/random-name
```

---

### Add Name

Adds a new name to the available list.

**Endpoint**: `POST /api/random-name?name={name}`

**Parameters**:
- `name` (required): The name to add

**Response**:
```json
{
  "success": true,
  "message": "Name 'John' added successfully",
  "data": null
}
```

**Example**:
```bash
curl -X POST "http://localhost:8080/api/random-name?name=John"
```

**Error Response** (empty name):
```json
{
  "success": false,
  "message": "Name cannot be empty",
  "data": null
}
```

---

### List All Names

Returns all available names with count.

**Endpoint**: `GET /api/names`

**Response**:
```json
{
  "success": true,
  "message": "Retrieved 10 names",
  "data": [
    "Alice",
    "Bob",
    "Charlie",
    "Diana",
    "Eve",
    "Frank",
    "Grace",
    "Henry",
    "Ivy",
    "Jack"
  ]
}
```

**Example**:
```bash
curl http://localhost:8080/api/names
```

---

### Delete Name

Removes a specific name from the list.

**Endpoint**: `DELETE /api/names/{name}`

**Path Parameters**:
- `name`: The name to delete (URL encoded)

**Response** (success):
```json
{
  "success": true,
  "message": "Name 'John' removed successfully",
  "data": null
}
```

**Response** (not found):
```json
{
  "success": false,
  "message": "Name 'John' not found",
  "data": null
}
```

**Example**:
```bash
curl -X DELETE "http://localhost:8080/api/names/John"
```

---

### Health Check

Returns the health status of the backend service.

**Endpoint**: `GET /api/health`

**Response**:
```json
{
  "status": "UP",
  "namesCount": 10
}
```

**Example**:
```bash
curl http://localhost:8080/api/health
```

---

## Actuator Endpoints

Spring Boot Actuator provides additional monitoring endpoints.

### Health Details

**Endpoint**: `GET /actuator/health`

**Response**:
```json
{
  "status": "UP",
  "components": {
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 250790436864,
        "free": 100000000000,
        "threshold": 10485760,
        "exists": true
      }
    },
    "ping": {
      "status": "UP"
    }
  }
}
```

---

### Prometheus Metrics

**Endpoint**: `GET /actuator/prometheus`

Returns metrics in Prometheus format for monitoring and alerting.

**Example**:
```bash
curl http://localhost:8080/actuator/prometheus
```

**Sample Metrics**:
```
# HELP http_server_requests_seconds  
# TYPE http_server_requests_seconds summary
http_server_requests_seconds_count{method="GET",status="200",uri="/api/random-name"} 150.0
http_server_requests_seconds_sum{method="GET",status="200",uri="/api/random-name"} 0.523

# HELP jvm_memory_used_bytes The amount of used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{area="heap",id="PS Eden Space",} 2.5165824E7
```

---

## Error Responses

All endpoints return consistent error responses:

**Format**:
```json
{
  "success": false,
  "message": "Error description",
  "data": null
}
```

**HTTP Status Codes**:
- `200 OK`: Successful request
- `400 Bad Request`: Invalid input
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

---

## CORS

The API supports CORS with the following configuration:
- **Allowed Origins**: `*` (all origins)
- **Allowed Methods**: `GET`, `POST`, `DELETE`, `OPTIONS`
- **Allowed Headers**: `Content-Type`

---

## Rate Limiting

Currently, no rate limiting is enforced. In production, consider implementing rate limiting at the ingress level.

---

## Examples

### Complete Workflow

```bash
# 1. Check health
curl http://localhost:8080/api/health

# 2. Get current names
curl http://localhost:8080/api/names

# 3. Add new names
curl -X POST "http://localhost:8080/api/random-name?name=Sarah"
curl -X POST "http://localhost:8080/api/random-name?name=Michael"

# 4. Get random name
curl http://localhost:8080/api/random-name

# 5. Delete a name
curl -X DELETE "http://localhost:8080/api/names/Sarah"

# 6. Verify deletion
curl http://localhost:8080/api/names
```

### Using JavaScript

```javascript
// Get random name
async function getRandomName() {
  const response = await fetch('/api/random-name');
  const data = await response.json();
  console.log(data.name);
}

// Add name
async function addName(name) {
  const response = await fetch(`/api/random-name?name=${encodeURIComponent(name)}`, {
    method: 'POST'
  });
  const result = await response.json();
  console.log(result.message);
}

// List all names
async function listNames() {
  const response = await fetch('/api/names');
  const result = await response.json();
  console.log(result.data); // Array of names
}

// Delete name
async function deleteName(name) {
  const response = await fetch(`/api/names/${encodeURIComponent(name)}`, {
    method: 'DELETE'
  });
  const result = await response.json();
  console.log(result.message);
}
```

---

## Notes

- All timestamps are in Unix epoch format (milliseconds)
- Names are stored in memory and will reset on application restart
- Thread-safe operations using `CopyOnWriteArrayList`
- Default names are provided on startup
