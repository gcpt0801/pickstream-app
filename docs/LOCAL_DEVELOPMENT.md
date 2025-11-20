# Local Development Guide

This guide helps you set up and run PickStream locally for development.

## Prerequisites

### Required Software

- **Java 17 or later** - [Download](https://adoptium.net/)
- **Maven 3.9+** - [Download](https://maven.apache.org/download.cgi)
- **Docker Desktop** - [Download](https://www.docker.com/products/docker-desktop)
- **Docker Compose** - Included with Docker Desktop
- **Git** - [Download](https://git-scm.com/downloads)

### Optional Tools

- **IntelliJ IDEA** or **Eclipse** - For Java development
- **VS Code** - For frontend development
- **Postman** or **cURL** - For API testing

## Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/pickstream-app.git
cd pickstream-app
```

### 2. Run with Docker Compose (Easiest)

This is the simplest way to run the entire stack:

```bash
# Start all services
./scripts/local-dev.sh start

# Or manually
docker-compose up --build
```

**Access**:
- Frontend: http://localhost:8081
- Backend: http://localhost:8080
- Health: http://localhost:8080/actuator/health

**Manage services**:
```bash
# View logs
./scripts/local-dev.sh logs

# Stop services
./scripts/local-dev.sh stop

# Restart services
./scripts/local-dev.sh restart

# Check status
./scripts/local-dev.sh status
```

### 3. Run Backend Locally

For backend development without Docker:

```bash
cd services/backend

# Install dependencies and run tests
./mvnw clean test

# Run the application
./mvnw spring-boot:run
```

The backend will start on http://localhost:8080

**Or with Maven installed globally**:
```bash
mvn clean install
mvn spring-boot:run
```

### 4. Run Frontend Locally

For frontend development:

**Option A: With Docker**
```bash
cd services/frontend
docker build -t pickstream-frontend .
docker run -p 8081:80 \
  -e BACKEND_SERVICE_HOST=host.docker.internal \
  -e BACKEND_SERVICE_PORT=8080 \
  pickstream-frontend
```

**Option B: With Nginx**
```bash
# Install nginx (macOS)
brew install nginx

# Or (Ubuntu/Debian)
sudo apt-get install nginx

# Copy files to nginx html directory
cp -r services/frontend/public/* /usr/local/var/www/

# Start nginx
nginx
```

**Option C: Simple HTTP server (for testing)**
```bash
cd services/frontend/public
python3 -m http.server 8081
```

Access at http://localhost:8081

## Development Workflow

### Backend Development

**1. Project Structure**
```
services/backend/
├── src/main/java/com/pickstream/
│   ├── PickstreamApplication.java      # Main entry point
│   ├── controller/
│   │   └── RandomNameController.java   # REST endpoints
│   ├── service/
│   │   └── NameService.java           # Business logic
│   └── model/
│       ├── NameResponse.java          # Response models
│       └── ApiResponse.java
├── src/main/resources/
│   └── application.yml                # Configuration
├── src/test/java/                     # Test files
├── pom.xml                            # Maven dependencies
└── Dockerfile                         # Container image
```

**2. Making Changes**

Edit Java files in your IDE:
```bash
# Open in IntelliJ IDEA
idea services/backend

# Or Eclipse
eclipse services/backend
```

**3. Run Tests**
```bash
cd services/backend

# Run all tests
./mvnw test

# Run specific test
./mvnw test -Dtest=RandomNameControllerTest

# Run with coverage
./mvnw test jacoco:report
# View coverage: target/site/jacoco/index.html
```

**4. Hot Reload**

Spring Boot DevTools enables hot reload:
```xml
<!-- Already included in pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <scope>runtime</scope>
    <optional>true</optional>
</dependency>
```

Just save your files and the app will restart automatically!

**5. Debug**

In IntelliJ IDEA:
1. Set breakpoints in your code
2. Click "Debug" button
3. Make API request
4. Debugger will stop at breakpoints

**6. Build Docker Image**
```bash
cd services/backend
docker build -t pickstream-backend:dev .
docker run -p 8080:8080 pickstream-backend:dev
```

### Frontend Development

**1. Project Structure**
```
services/frontend/
├── public/
│   ├── index.html           # Main HTML
│   ├── css/
│   │   └── style.css       # Styles
│   └── js/
│       └── app.js          # JavaScript
├── nginx.conf              # Nginx configuration
└── Dockerfile              # Container image
```

**2. Making Changes**

Edit files in your favorite editor:
```bash
# VS Code
code services/frontend

# Or any text editor
```

**3. Test Changes**

If using Docker Compose, just refresh the browser after saving files:
```bash
# Rebuild frontend only
docker-compose up --build frontend
```

**4. Test API Integration**

Use browser console or curl:
```javascript
// In browser console (F12)
fetch('/api/random-name')
  .then(r => r.json())
  .then(console.log);
```

**5. CSS Changes**

Edit `public/css/style.css` and refresh browser. No rebuild needed!

**6. JavaScript Changes**

Edit `public/js/app.js` and refresh browser (hard refresh: Ctrl+Shift+R)

## Testing

### Manual API Testing

**Using cURL**:
```bash
# Health check
curl http://localhost:8080/api/health

# Get random name
curl http://localhost:8080/api/random-name

# Add name
curl -X POST "http://localhost:8080/api/random-name?name=TestName"

# List all
curl http://localhost:8080/api/names

# Delete name
curl -X DELETE "http://localhost:8080/api/names/TestName"
```

**Using Postman**:
1. Import collection from `docs/postman_collection.json` (if available)
2. Set base URL: `http://localhost:8080`
3. Run requests

### Automated Tests

**Backend**:
```bash
cd services/backend
./mvnw test                    # Unit tests
./mvnw verify                  # Integration tests
./mvnw test jacoco:report      # With coverage
```

**Load Testing** (optional):
```bash
# Install Apache Bench
# macOS: brew install httpd
# Ubuntu: sudo apt-get install apache2-utils

# Run load test
ab -n 1000 -c 10 http://localhost:8080/api/random-name
```

## Configuration

### Backend Configuration

Edit `services/backend/src/main/resources/application.yml`:

```yaml
server:
  port: 8080  # Change port if needed

spring:
  application:
    name: pickstream-backend

logging:
  level:
    root: INFO
    com.pickstream: DEBUG  # Change to DEBUG for more logs
```

### Environment Variables

Set environment variables:

**Backend**:
```bash
export SPRING_PROFILES_ACTIVE=development
export SERVER_PORT=8080
export LOGGING_LEVEL_COM_PICKSTREAM=DEBUG
```

**Frontend**:
```bash
export BACKEND_SERVICE_HOST=localhost
export BACKEND_SERVICE_PORT=8080
```

### Docker Compose Configuration

Edit `docker-compose.yml`:

```yaml
services:
  backend:
    environment:
      - SPRING_PROFILES_ACTIVE=development
      - LOGGING_LEVEL_COM_PICKSTREAM=DEBUG
  
  frontend:
    environment:
      - BACKEND_SERVICE_HOST=backend
      - BACKEND_SERVICE_PORT=8080
```

## Troubleshooting

### Backend Won't Start

**Issue**: Port 8080 already in use
```bash
# Find process using port 8080
# macOS/Linux
lsof -i :8080

# Windows
netstat -ano | findstr :8080

# Kill the process or change port
export SERVER_PORT=8081
./mvnw spring-boot:run
```

**Issue**: Maven dependencies not downloading
```bash
# Clear Maven cache
rm -rf ~/.m2/repository

# Re-download
./mvnw clean install -U
```

**Issue**: Java version mismatch
```bash
# Check Java version
java -version

# Should be Java 17+
# Install from https://adoptium.net/
```

### Frontend Issues

**Issue**: Can't connect to backend
- Check backend is running on port 8080
- Check `BACKEND_SERVICE_HOST` environment variable
- Check CORS configuration in backend

**Issue**: Static files not loading
- Check nginx configuration
- Verify files are in correct location
- Check browser console for 404 errors

### Docker Issues

**Issue**: Build fails
```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker-compose build --no-cache
```

**Issue**: Container won't start
```bash
# Check logs
docker-compose logs backend
docker-compose logs frontend

# Check status
docker-compose ps
```

## IDE Setup

### IntelliJ IDEA

1. Open project: `File > Open > pickstream-app`
2. Wait for Maven import
3. Configure JDK: `File > Project Structure > Project SDK > 17`
4. Run configuration:
   - Main class: `com.pickstream.PickstreamApplication`
   - Module: `pickstream-backend`
   - JRE: 17

### VS Code

1. Install extensions:
   - Java Extension Pack
   - Spring Boot Extension Pack
2. Open folder: `services/backend`
3. Press F5 to debug

## Tips and Tricks

### Speed Up Maven Builds

Add to `~/.m2/settings.xml`:
```xml
<settings>
  <localRepository>/path/to/.m2/repository</localRepository>
  <offline>false</offline>
  <mirrors>
    <mirror>
      <id>central</id>
      <url>https://repo.maven.apache.org/maven2</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
</settings>
```

### Watch Mode for Frontend

Use browser extensions:
- **Live Server** (VS Code extension)
- **Browser Sync** for automatic refresh

### Database (Future Enhancement)

Currently using in-memory storage. To add database:
1. Add Spring Data JPA dependency
2. Configure database connection
3. Create entity classes
4. Update service layer

## Next Steps

- Read [API Documentation](API.md)
- Check [Deployment Guide](DEPLOYMENT.md)
- Review project architecture
- Start making changes!

## Getting Help

- Check logs: `./scripts/local-dev.sh logs`
- Review error messages
- Check GitHub issues
- Ask in team chat
