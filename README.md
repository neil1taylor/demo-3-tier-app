# Three-Tier Java Web Application

This repository contains a simple Java web application demonstrating a 3-tier architecture pattern for deployment on IBM Cloud ROKS with OpenShift Virtualization.

## Architecture

```
Web Tier (NGINX) → Application Tier (Tomcat/Java) → Database Tier (PostgreSQL)
```

## Features

- RESTful API for user management
- Real-time health monitoring
- Database connectivity with PostgreSQL
- Responsive web interface
- Automatic error handling
- Cross-tier communication demonstration

## Repository Structure

```
three-tier-java-app/
├── README.md
├── pom.xml
├── scripts/
│   ├── build.sh
│   └── deploy.sh
└── src/
    └── main/
        ├── java/com/threetier/webapp/
        │   ├── DatabaseConnection.java
        │   ├── User.java
        │   ├── UserServlet.java
        │   └── HealthServlet.java
        └── webapp/
            ├── index.html
            └── WEB-INF/web.xml
```

## API Endpoints

- `GET /api/users/` - List all users
- `POST /api/users/` - Create new user
- `GET /health` - Health check with database connectivity

## Local Development

### Prerequisites
- Java 11 or higher
- Maven 3.6+
- PostgreSQL (for local testing)

### Build
```bash
./scripts/build.sh
```

### Deploy to Tomcat
```bash
./scripts/deploy.sh
```

### Access Application
- Main App: http://localhost:8080/
- Health Check: http://localhost:8080/health
- API: http://localhost:8080/api/users/

## Deployment

This application is designed to be deployed on:
- IBM Cloud Red Hat OpenShift Kubernetes Service (ROKS)
- OpenShift Virtualization (OCP-V)
- CentOS Stream 9 Virtual Machines
- OpenShift Data Foundation (ODF) storage

## Environment Variables

The application uses the following environment variables for database connectivity:
- `DB_HOST`: Database host (default: db-primary-service)
- `DB_PORT`: Database port (default: 5432)
- `DB_NAME`: Database name (default: appdb)
- `DB_USER`: Database user (default: appuser)
- `DB_PASSWORD`: Database password (default: apppassword)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
