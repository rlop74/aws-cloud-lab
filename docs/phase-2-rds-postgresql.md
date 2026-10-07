# Phase 2 — RDS PostgreSQL / Private Data Tier

## Overview

Phase 2 extended the Phase 1 architecture by adding a private managed PostgreSQL data tier using Amazon RDS.

The goal was to allow the private FastAPI application to communicate securely with PostgreSQL without exposing the database to the Internet.

This phase focused on database network isolation, RDS subnet placement, Security Group relationships, DNS and TCP troubleshooting, PostgreSQL authentication, environment-based application configuration, application-to-database integration, and database failure handling.

## Architecture

The Phase 1 application path was extended with RDS PostgreSQL:

```text
Internet
    |
    v
Internet Gateway
    |
    v
Application Load Balancer :80
    |
    v
Private App EC2 :8000
    |
    v
PostgreSQL :5432
    |
    v
RDS PostgreSQL
Private DB Subnet
```

The database tier uses dedicated private database subnets:

```text
                    VPC
                     |
          +----------+----------+
          |                     |
        AZ 1a                 AZ 1b
          |                     |
Private DB Subnet A     Private DB Subnet B
          |                     |
          +----------+----------+
                     |
              DB Subnet Group
                     |
              RDS PostgreSQL
```

The final Phase 2 architecture follows several important constraints:

- RDS PostgreSQL is not publicly accessible.
- The application connects to RDS using the RDS DNS endpoint rather than a hardcoded private IP address.
- The application EC2 instance and current Single-AZ RDS instance are both located in `us-east-1a`.
- The DB subnet group contains private database subnets across multiple Availability Zones.
- Multiple subnets in a DB subnet group do not mean multiple database instances are running.
- The database itself remains Single-AZ during Phase 2.
- Multi-AZ RDS deployment is introduced later during the high-availability phase.

---

## Private Database Subnets

Dedicated private subnets were created for the database tier rather than placing RDS in the application subnet.

This separates the application and database layers and provides cleaner network segmentation.

A subnet belongs to a specific Availability Zone, while a Security Group belongs to the VPC rather than to an individual subnet or Availability Zone.

```text
Subnet          -> AZ-specific
Security Group  -> VPC-level
```

### DB Subnet Group

Amazon RDS uses a DB subnet group to define the subnets in which AWS is allowed to place the database.

The DB subnet group contains private database subnets across at least two Availability Zones:

```text
DB Subnet Group
├── Private DB Subnet A -> us-east-1a
└── Private DB Subnet B -> us-east-1b
```

Having subnets from multiple Availability Zones in the subnet group does not by itself make the database Multi-AZ.

For the current Single-AZ deployment, the RDS instance was placed in `us-east-1a`.

The application EC2 instance was also running in `us-east-1a`, keeping the normal application-to-database traffic within the same Availability Zone during this phase.

---

## RDS Security Group

A dedicated database Security Group was created:

```text
AWSCloudLab-VPC-DB-SG
```

The database allows PostgreSQL traffic from the application Security Group:

```text
Protocol: TCP
Port:     5432
Source:   App Security Group
```

The resulting Security Group relationship is:

```text
Internet
    |
    v
ALB-SG
    |
 TCP :8000
    v
App-SG
    |
 TCP :5432
    v
DB-SG
```

The database does not permit PostgreSQL `5432` directly from the Internet.

Instead, the DB Security Group trusts the App Security Group. Instances associated with the allowed App Security Group can reach PostgreSQL, subject to the rest of the network path being configured correctly.

The ALB does not require PostgreSQL access because each infrastructure tier communicates only with the next required tier:

```text
Internet
    |
    v
ALB
    |
    v
Application
    |
    v
Database
```

---

## RDS Endpoint and DNS

Amazon RDS provides a DNS endpoint similar to:

```text
awscloudlab-database-1.xxxxxxxxx.us-east-1.rds.amazonaws.com
```

The application connects using this endpoint instead of hardcoding the database's private IP address.

DNS resolution was tested from the application EC2 instance:

```bash
nslookup <RDS-ENDPOINT>
```

The endpoint resolved to a private VPC address:

```text
10.x.x.x
```

The relationship is:

```text
RDS DNS Endpoint
       |
       v
Private VPC IP
```

A successful `nslookup` proves that DNS resolution works.

It does **not** prove that PostgreSQL is reachable.

Likewise, `ping` is not an appropriate PostgreSQL connectivity test because it tests ICMP rather than the TCP connection PostgreSQL uses on port `5432`.

---

## Layer-by-Layer Connectivity Testing

Rather than testing the entire application path at once, database connectivity was validated one layer at a time.

### TCP Connectivity

TCP connectivity from the application EC2 instance to RDS was tested with:

```bash
nc -vz <RDS-ENDPOINT> 5432
```

The initial result was a timeout.

At that point, the state of the connection path was:

```text
DNS resolution       ✓
TCP 5432             ✗
PostgreSQL auth      ?
Application -> DB     ?
```

Because DNS resolution succeeded but the TCP connection timed out, troubleshooting remained at the network and security layer instead of moving prematurely to PostgreSQL credentials or application configuration.

The required RDS Security Group rule was:

```text
Inbound:
PostgreSQL / TCP 5432
Source: App-SG
```

After correcting the Security Group, the TCP test:

```bash
nc -vz <RDS-ENDPOINT> 5432
```

succeeded.

This validated the path:

```text
App EC2
   |
   v
VPC Networking
   |
   v
DB Security Group
   |
   v
RDS :5432
      ✓
```

### Troubleshooting Ladder

The database path was validated progressively:

```text
nslookup succeeds
        |
        v
DNS resolution works
        |
        v
nc :5432 succeeds
        |
        v
TCP/network path works
        |
        v
psql succeeds
        |
        v
PostgreSQL authentication works
        |
        v
FastAPI query succeeds
        |
        v
Application integration works
```

Testing each layer independently made it possible to identify which layer was failing instead of randomly changing infrastructure or application settings.

---

## PostgreSQL Authentication

After TCP connectivity succeeded, PostgreSQL authentication was tested directly from the application EC2 instance using the PostgreSQL client:

```bash
psql -h <RDS-ENDPOINT> -p 5432 -U <DB-USER> -d <DB-NAME>
```

Successful authentication proved:

```text
DNS resolution            ✓
TCP 5432 connectivity     ✓
PostgreSQL authentication ✓
```

This validated the AWS networking path and database authentication independently of the FastAPI application.

Only after these lower layers worked was the application itself integrated with PostgreSQL.

---

## FastAPI Database Configuration

Database connection information is not hardcoded directly inside `main.py`.

The application reads the following environment variables:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
```

During Phase 2, these values are supplied through a local `.env` file on the application instance.

Example:

```text
DB_HOST=<RDS-ENDPOINT>
DB_PORT=5432
DB_NAME=<DB-NAME>
DB_USER=<DB-USER>
DB_PASSWORD=<DB-PASSWORD>
```

The real `.env` file is intentionally excluded from Git:

```gitignore
.env
```

An `.env.example` file is committed to the repository to document the required configuration keys without storing the real database credentials.

The resulting configuration flow is:

```text
.env
 |
 v
python-dotenv
 |
 v
Environment Variables
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

The `.env` approach is used for the current lab phase. Manually managed database secrets can later be replaced with an AWS-native secrets-management approach.

### Dependencies

The application uses:

- `python-dotenv` to load variables from `.env` into the application's environment.
- `psycopg` as the PostgreSQL driver used by Python to communicate with RDS.

The dependencies were added with:

```bash
uv add python-dotenv "psycopg[binary]"
```

The `[binary]` extra installs Psycopg using its precompiled binary implementation rather than requiring the PostgreSQL client components to be compiled locally.

---

## Database Health Endpoint

A database-backed endpoint was added to FastAPI:

```text
GET /db-health
```

Unlike the basic `/health` endpoint, `/db-health` attempts to establish a real PostgreSQL connection and execute a query.

The final implementation was:

```python
from fastapi import FastAPI, HTTPException
import os
from dotenv import load_dotenv
import psycopg

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Hello Dudong"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/db-health")
def db_health():
    try:
        with psycopg.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=3,
        ) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT version()")
                db_version = cur.fetchone()
                print(db_version)
                return {"db_status": "healthy"}
    except psycopg.Error as e:
        print(e)
        raise HTTPException(
            status_code=503,
            detail="Database unavailable",
        )
```

The `connect_timeout=3` setting prevents a blocked or unreachable database connection from hanging for an extended period.

### End-to-End Validation

The `/db-health` endpoint validates the complete application and database path:

```text
Internet
   |
   v
ALB :80
   |
   v
FastAPI :8000
   |
   v
psycopg
   |
   v
RDS :5432
   |
   v
PostgreSQL Query
```

The endpoint was tested through the ALB:

```bash
curl http://<ALB-DNS>/db-health
```

Successful response:

```json
{ "db_status": "healthy" }
```

This proved more than direct EC2-to-RDS connectivity. It validated the complete request path from the public ALB through FastAPI and into PostgreSQL.

---

## Failure Handling and Break-Fix Test

After the complete database path was working, the database dependency was deliberately broken to validate failure handling.

The DB Security Group rule permitting:

```text
App-SG -> PostgreSQL TCP 5432
```

was removed.

The resulting system state was:

```text
Internet -> ALB               ✓
ALB -> FastAPI                ✓
FastAPI application running  ✓
App -> RDS :5432              ✗
```

The database health endpoint was then requested through the ALB:

```bash
curl http://<ALB-DNS>/db-health
```

The PostgreSQL connection reached the configured three-second timeout:

```text
connection timeout expired
```

FastAPI caught the resulting `psycopg.Error` and returned:

```text
HTTP/1.1 503 Service Unavailable
```

with:

```json
{ "detail": "Database unavailable" }
```

Returning HTTP `503` accurately represents that the application is running but one of its required dependencies is unavailable.

The complete failure path was:

```text
DB Security Group rule removed
        |
        v
TCP :5432 blocked
        |
        v
3-second connection timeout
        |
        v
psycopg.Error
        |
        v
FastAPI exception handling
        |
        v
HTTP 503
        |
        v
{"detail":"Database unavailable"}
```

The Security Group rule was then restored:

```text
DB-SG
PostgreSQL TCP 5432
Source: App-SG
```

The same endpoint returned successfully again:

```json
{ "db_status": "healthy" }
```

The full break/fix test therefore demonstrated:

```text
DB SG rule present
      |
      v
DB connection succeeds
      |
      v
HTTP 200
      |
      v
{"db_status":"healthy"}

            ↓ break dependency

DB SG rule removed
      |
      v
TCP :5432 blocked
      |
      v
Connection timeout
      |
      v
HTTP 503
      |
      v
{"detail":"Database unavailable"}

            ↓ restore dependency

DB SG rule restored
      |
      v
HTTP 200
      |
      v
{"db_status":"healthy"}
```

This validated both failure detection and recovery rather than testing only the successful state.

---

## Rebuilding the Application EC2 Instance

Because the real `.env` file is intentionally excluded from Git, recreating the application EC2 instance requires restoring its environment-specific database configuration.

After rebuilding the application instance:

1. Clone the repository.
2. Run `uv sync`.
3. Create `.env` with the required RDS configuration.
4. Start or restart Uvicorn so the application loads the environment variables.

If `DB_HOST` is missing, Psycopg may attempt to connect through a local PostgreSQL Unix socket instead of connecting to the RDS endpoint.

This reinforced the distinction between application code stored in Git and environment-specific configuration that must be supplied separately.

---

## Key Lessons

Phase 2 established several database, networking, application-integration, and troubleshooting concepts:

- RDS can remain completely private while still serving an application running inside the VPC.
- Dedicated database subnets provide separation between the application and data tiers.
- A DB subnet group defines where RDS may be placed but does not itself make a database Multi-AZ.
- Subnets are Availability Zone-specific, while Security Groups operate at the VPC level.
- Security Group references can restrict PostgreSQL access to the application tier without relying on specific EC2 IP addresses.
- The ALB does not require database access; traffic should follow the intended application architecture from ALB to application to database.
- Applications should use the RDS DNS endpoint rather than hardcoding a database private IP.
- Successful DNS resolution does not prove TCP connectivity.
- Successful TCP connectivity does not prove PostgreSQL authentication.
- Successful PostgreSQL authentication does not prove application integration.
- Testing DNS, TCP, authentication, and application behavior independently makes failures easier to isolate.
- `ping` is not a substitute for testing the actual TCP service being troubleshot.
- Environment-specific database configuration should remain outside application source code.
- Sensitive `.env` files should not be committed to Git.
- `.env.example` can document required configuration without exposing credentials.
- Dependency health endpoints should return an appropriate failure status when a required dependency is unavailable.
- Deliberately breaking infrastructure after deployment is useful for validating failure behavior and recovery.

---

## Phase 2 Complete

By the end of Phase 2:

- A private Amazon RDS PostgreSQL database was deployed.
- Dedicated private database subnets were created across multiple Availability Zones.
- A DB subnet group was configured for RDS placement.
- The Phase 2 database remained Single-AZ.
- PostgreSQL access was restricted to the application Security Group on TCP `5432`.
- The application resolved RDS through its private DNS endpoint.
- EC2-to-RDS TCP connectivity was validated independently.
- PostgreSQL authentication was validated independently.
- Database configuration was moved to environment variables rather than hardcoded application values.
- The real `.env` file was excluded from Git while `.env.example` documented the required configuration.
- FastAPI successfully connected to PostgreSQL using Psycopg.
- `/db-health` validated the database dependency with a real PostgreSQL query.
- The complete ALB → FastAPI → RDS request path was successfully tested.
- Database connectivity was deliberately broken by removing the Security Group rule.
- The application correctly returned `503 Service Unavailable` while the database was unreachable.
- Restoring the Security Group rule restored the application-to-database path.

The final Phase 2 request path was:

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
Private RDS PostgreSQL :5432
```

The stack was validated layer-by-layer using:

```text
nslookup -> DNS resolution
nc       -> TCP connectivity
psql     -> PostgreSQL authentication
FastAPI  -> Application integration
ALB      -> End-to-end request path
```
