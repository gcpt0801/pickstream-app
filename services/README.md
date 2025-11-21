# Services

This folder contains the microservices that make up the Pickstream application.

## Structure

```
services/
├── backend/          # Spring Boot REST API
└── frontend/         # Nginx web server with static UI
```

## Backend Service

**Technology:** Spring Boot 3.2.0 with Java 17

**Purpose:** Provides REST API endpoints for the application

**Key Files:**
- `src/main/java/` - Java source code
- `pom.xml` - Maven dependencies and build configuration
- `Dockerfile` - Container image definition

**Endpoints:**
- `GET /api/random-name` - Returns a random name
- `GET /api/names` - Returns list of all names
- `GET /actuator/health` - Health check endpoint

**Local Development:**
```bash
cd services/backend
mvn spring-boot:run
```

Access at: http://localhost:8080

## Frontend Service

**Technology:** Nginx with HTML/CSS/JavaScript

**Purpose:** Serves the user interface and proxies API requests to backend

**Key Files:**
- `public/` - Static HTML, CSS, and JavaScript files
- `nginx.conf` - Nginx configuration with backend proxy
- `Dockerfile` - Container image definition

**How it works:**
- Serves static files from `/usr/share/nginx/html`
- Proxies `/api/*` requests to the backend service
- Uses environment variables to configure backend location

**Local Development:**
```bash
cd services/frontend
# Edit public/index.html or public/js/app.js
# Test with docker-compose from project root
```

## Building Docker Images

Images are automatically built by the CI/CD pipeline when you push to main.

**Manual build (optional):**
```bash
# Backend
docker build -t pickstream-backend ./services/backend

# Frontend  
docker build -t pickstream-frontend ./services/frontend
```

## Testing Locally

Use Docker Compose from the project root:
```bash
docker-compose up
```

Access the application at: http://localhost:8081

## Environment Variables

### Backend
- `SPRING_PROFILES_ACTIVE` - Spring profile (default: development)

### Frontend
- `BACKEND_SERVICE_HOST` - Backend hostname (default: pickstream-backend)
- `BACKEND_SERVICE_PORT` - Backend port (default: 8080)

These are automatically set in Kubernetes by the Helm chart.
