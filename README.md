# AWS Cloud Lab

A hands-on cloud engineering project for building, securing, automating, monitoring, and operating application infrastructure on AWS.

The application is intentionally simple so the focus remains on cloud infrastructure, Linux, networking, high availability, observability, Infrastructure as Code, automation, and DevOps practices.

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
  - Auto Scaling
  - RDS PostgreSQL
  - IAM
  - CloudWatch
- Linux
- Git
- Docker
- Terraform
- GitHub Actions

Additional infrastructure and automation will be added as the project progresses.

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

This project progressively explores:

- AWS networking and VPC architecture
- EC2 and Linux administration
- Amazon RDS and managed databases
- Load balancing and high availability
- Auto Scaling and self-healing infrastructure
- CloudWatch monitoring, logging, and alarms
- Docker and containerization
- Infrastructure as Code with Terraform
- CI/CD with GitHub Actions
- IAM and cloud security
- Python and Bash automation
- AWS Systems Manager
- Infrastructure troubleshooting and failure analysis

## Architecture

The architecture evolves throughout the project as additional cloud engineering concepts are introduced.

### Phase 1 — Manual AWS Infrastructure

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

---

### Phase 2 — RDS PostgreSQL / Private Data Tier

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

A DB subnet group spans multiple Availability Zones while the initial database deployment remains Single-AZ.

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

Database failure handling was tested by deliberately blocking application-to-database traffic. The application detected the unavailable dependency and returned `503 Service Unavailable`, then recovered after connectivity was restored.

---

### Phase 3 — CloudWatch / Observability

Added monitoring and observability using Amazon CloudWatch.

AWS service metrics were reviewed for EC2, the Application Load Balancer, and RDS. A CloudWatch dashboard and alarms were created to monitor infrastructure and application conditions.

A CloudWatch Agent was installed and configured on EC2 to collect guest operating system metrics and application logs.

```text
EC2 / ALB / RDS
      |
      v
CloudWatch Metrics
      |
      +--> Dashboard
      |
      +--> Alarms

EC2 Guest OS / Application
      |
      v
CloudWatch Agent
      |
      +--> Guest OS Metrics
      |
      +--> Application Logs
                |
                v
          CloudWatch Logs
```

The monitoring pipeline was validated end-to-end by publishing guest OS memory metrics and application log events to CloudWatch.

The phase also documented a layer-by-layer troubleshooting process for diagnosing failures in the application logging and telemetry pipeline.

---

### Phase 4 — Multi-AZ / High Availability

Designed the application architecture to remove single-instance and single-Availability-Zone dependencies.

```text
                         Internet
                            |
                            v
                 Application Load Balancer
                       /           \
                      /             \
                   AZ-1a           AZ-1b
                     |               |
                     v               v
                 App EC2         App EC2
                     \               /
                      \             /
                       Target Group
                            ^
                            |
                    Auto Scaling Group
                    Min:     2
                    Desired: 2
                    Max:     4

                 RDS Multi-AZ Deployment
                       /           \
                      /             \
                  Primary         Standby
                   AZ-1a           AZ-1b
```

The high-availability design includes:

- Public, private application, and private database subnets across two Availability Zones
- Independent outbound NAT paths for each application Availability Zone
- Application Load Balancer spanning multiple Availability Zones
- Health-based traffic distribution through an ALB target group
- Launch Templates for reproducible application instances
- Auto Scaling Group across both private application subnets
- Minimum and desired capacity of two application instances
- Instance replacement and self-healing behavior
- RDS Multi-AZ primary/standby architecture
- Security Group-based trust between ALB, application, and database tiers
- IAM instance roles and AWS-managed application secrets

The Auto Scaling configuration separates high availability from demand-based scaling. A desired capacity of two maintains the redundant application fleet, while additional scaling policies can later increase capacity in response to workload metrics.

This architecture will serve as the target infrastructure for the Terraform implementation, where the complete environment will be reproduced as code.

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

### Phase 3 — CloudWatch / Observability ✅

- EC2, ALB, and RDS service metrics
- CloudWatch dashboard
- CloudWatch alarms
- CloudWatch Agent
- Guest OS metrics
- Application log collection
- IAM role-based telemetry publishing
- Monitoring pipeline troubleshooting and recovery workflow

### Phase 4 — Multi-AZ / High Availability ✅

- Multi-AZ network architecture
- Per-AZ application and database subnet design
- Per-AZ NAT architecture
- ALB health-based traffic distribution
- Launch Template design
- Auto Scaling Group configuration
- Multi-AZ instance placement
- Min / desired / max capacity behavior
- EC2 and ELB health-check strategy
- Self-healing architecture
- RDS Multi-AZ design
- Instance and Availability Zone failure behavior

### Phase 5 — Docker 🚧

- Dockerfile
- Container images and containers
- Containerize FastAPI
- Ports and container networking
- Environment variables
- Container logs
- Build, run, and debug lifecycle

### Upcoming

- Phase 6 — Terraform / Infrastructure as Code
- Phase 7 — CI/CD with GitHub Actions
- Phase 8 — Python/Bash Automation
- Phase 9 — Systems Manager / Session Manager

## Documentation

Detailed implementation notes, architecture decisions, troubleshooting, and lessons learned are maintained throughout the project.

- Phase 1 — Manual AWS Infrastructure
- Phase 2 — RDS PostgreSQL / Private Data Tier
- Phase 3 — CloudWatch / Observability
- Phase 4 — Multi-AZ / High Availability

## Status

🚧 In development — Phase 5: Docker
