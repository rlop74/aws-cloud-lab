# AWS Cloud Lab

A hands-on cloud engineering project for learning how to deploy, secure, automate, and operate an application on AWS.

The application is intentionally simple so the focus remains on cloud infrastructure, Linux, networking, automation, and DevOps practices.

## Application

A minimal FastAPI application with three endpoints:

- `GET /` — Returns a simple response
- `GET /health` — Application health check
- `GET /db-health` — Validates PostgreSQL database connectivity

Database configuration is provided through environment variables. See `.env.example` for the required variables.

## Tech Stack

- Python
- FastAPI
- PostgreSQL
- AWS
  - VPC
  - EC2
  - Application Load Balancer
  - RDS PostgreSQL
- Linux
- Git

Additional infrastructure and tooling will be added as the project progresses.

## Running Locally

Install dependencies:

```bash
uv sync
```

Create a local environment file:

```bash
cp .env.example .env
```

Add the required database configuration to `.env`.

Start the application:

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000
```

## Project Goals

This project will progressively explore:

- AWS networking and VPC architecture
- EC2 and Linux administration
- Amazon RDS and managed databases
- Load balancing and high availability
- Infrastructure as Code with Terraform
- Docker and containerization
- CI/CD with GitHub Actions
- IAM and cloud security
- Monitoring and logging
- Python and Bash automation
- AWS Systems Manager
- Infrastructure troubleshooting

## Architecture

The architecture will evolve throughout the project as new cloud engineering concepts are implemented.

### Stage 1 — Manual AWS Infrastructure

Deployed the FastAPI application to a private EC2 instance behind an Application Load Balancer.

The environment includes a custom VPC, public and private subnets, a bastion host for administrative access, and a NAT instance for outbound Internet connectivity.

#### Application Traffic

```text
Internet
   |
   v
Application Load Balancer :80
   |
   v
Private App EC2 :8000
   |
   v
FastAPI
```

#### Administrative Access

```text
Local Machine
   |
  SSH
   v
Bastion Host
   |
  SSH
   v
Private App EC2
```

The private key remains on the local machine while the bastion acts as the jump host to reach the private application instance.

#### Private Outbound Internet Access

```text
Private App EC2
   |
   v
NAT Instance
   |
   v
Internet Gateway
   |
   v
Internet
```

The application instance has no public IP address. The NAT instance provides outbound Internet connectivity while keeping the application instance private.

Security Groups restrict communication between infrastructure layers rather than exposing the application directly to the Internet.

### Stage 2 — RDS PostgreSQL / Private Data Tier

Extended the architecture with a private Amazon RDS PostgreSQL database.

```text
Internet
   |
   v
Application Load Balancer :80
   |
   v
Private App EC2 / FastAPI :8000
   |
   v
RDS PostgreSQL :5432
```

The database is not publicly accessible and is deployed within dedicated private database subnets.

A DB subnet group spans multiple Availability Zones while the current database deployment remains Single-AZ.

Security Groups restrict PostgreSQL access to the application tier:

```text
Internet
   |
   v
ALB-SG
   |
 :8000
   v
App-SG
   |
 :5432
   v
DB-SG
```

The application connects to PostgreSQL using the RDS DNS endpoint and environment-based configuration.

The `/db-health` endpoint performs a real database connection to validate the complete application path:

```text
Internet
   |
   v
ALB
   |
   v
FastAPI
   |
   v
psycopg
   |
   v
RDS PostgreSQL
```

Database failure handling was also tested by deliberately blocking application-to-database traffic. The application detected the failed dependency and returned `503 Service Unavailable`, then recovered after connectivity was restored.

## Project Progress

### Phase 1 — Manual AWS Infrastructure ✅

- Custom VPC with public and private subnets
- Internet Gateway and route tables
- Bastion host for administrative access
- NAT instance for private outbound connectivity
- Private application EC2 instance
- Application Load Balancer and target group
- Security Group-based network access
- Manual networking and connectivity troubleshooting

### Phase 2 — RDS PostgreSQL / Private Data Tier ✅

- Private RDS PostgreSQL database
- Dedicated private database subnets
- DB subnet group spanning multiple Availability Zones
- App-SG → DB-SG access on TCP `5432`
- RDS DNS and PostgreSQL connectivity validation
- Environment-based database configuration
- FastAPI → PostgreSQL integration
- Database-backed `/db-health` endpoint
- Database failure and recovery testing

### Upcoming

- Phase 3 — CloudWatch / Observability
- Phase 4 — Multi-AZ / High Availability
- Phase 5 — Docker
- Phase 6 — Terraform
- Phase 7 — CI/CD
- Phase 8 — Python/Bash Automation
- Phase 9 — Systems Manager / Session Manager

## Documentation

Detailed implementation notes, architecture decisions, troubleshooting, and lessons learned:

- [Phase 1 — Manual AWS Infrastructure](docs/phase-1-manual-infrastructure.md)
- [Phase 2 — RDS PostgreSQL / Private Data Tier](docs/phase-2-rds-postgresql.md)

## Status

🚧 In development — Phase 2 complete
