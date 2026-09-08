# AWS Cloud Lab

A hands-on cloud engineering project for learning how to deploy, secure, automate, and operate an application on AWS.

The application is intentionally simple so the focus remains on cloud infrastructure, Linux, networking, automation, and DevOps practices.

## Application

A minimal FastAPI application with two endpoints:

- `GET /` — Returns a simple response
- `GET /health` — Health check endpoint

## Tech Stack

- Python
- FastAPI
- AWS
- Linux
- Git

Additional infrastructure and tooling will be added as the project progresses.

## Running Locally

Install dependencies:

```bash
uv sync
```

Start the development server:

```bash
uv run fastapi dev
```

## Project Goals

This project will progressively explore:

- AWS networking and VPC architecture
- EC2 and Linux administration
- Load balancing and high availability
- Infrastructure as Code with Terraform
- Docker and containerization
- CI/CD with GitHub Actions
- IAM and cloud security
- Monitoring and logging
- Python and Bash automation
- Infrastructure troubleshooting

## Architecture

The architecture will evolve throughout the project as new cloud engineering concepts are implemented.

### Stage 1

Deploy the FastAPI application to a single EC2 instance.

```text
Internet
   |
   v
  EC2
   |
   v
FastAPI
```

## Status

🚧 In development
