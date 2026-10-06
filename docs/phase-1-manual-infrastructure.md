# Phase 1 — Manual AWS Infrastructure

## Overview

Phase 1 established the initial AWS infrastructure manually through the AWS Management Console.

The goal was to deploy the FastAPI application on a private EC2 instance while providing controlled public application access, administrative access, and outbound Internet connectivity without assigning a public IP address to the application server.

This phase focused on understanding the underlying AWS networking and compute components before reproducing the architecture with Infrastructure as Code later in the project.

## Architecture

### Application Traffic

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
Target Group
    |
    v
Private App EC2 :8000
    |
    v
FastAPI
```

### Administrative Access

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

### Private Outbound Internet Access

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

The application EC2 instance remains private in the final Phase 1 architecture. Public HTTP traffic reaches it through the Application Load Balancer, administrative SSH access passes through the bastion host, and outbound Internet traffic passes through the NAT instance.

---

## VPC, Subnets, and Routing

A custom VPC was created using the CIDR block:

```text
10.0.0.0/16
```

The initial architecture included:

- Two public subnets in separate Availability Zones for the Application Load Balancer
- One private subnet for the application EC2 instance
- Public routing through an Internet Gateway
- Private outbound routing through a NAT instance

A subnet is considered public when its route table provides a route to an Internet Gateway. Naming a subnet "public" or "private" does not determine its connectivity.

### Public Route Table

```text
10.0.0.0/16 -> local
0.0.0.0/0   -> Internet Gateway
```

The `local` route enables routing between resources within the VPC CIDR.

The default route sends Internet-bound traffic to the Internet Gateway.

### Private Route Table

```text
10.0.0.0/16 -> local
0.0.0.0/0   -> NAT instance
```

The private application subnet does not route Internet-bound traffic directly to the Internet Gateway. Instead, its default route sends outbound traffic to the NAT instance.

### Networking Responsibilities

| Component      | Responsibility                                   |
| -------------- | ------------------------------------------------ |
| Route Table    | Determines where traffic is routed               |
| Security Group | Stateful traffic filtering at the resource level |
| Network ACL    | Stateless traffic filtering at the subnet level  |

Routing determines whether a network path exists, while Security Groups determine whether traffic is permitted across that path.

---

## Application EC2

The FastAPI application was deployed to an Amazon Linux EC2 instance.

The final application instance resides in the private subnet and does not have a public IP address.

### Application Setup

Git was installed using the Amazon Linux `dnf` package manager:

```bash
sudo dnf install git -y
```

The repository was cloned over HTTPS:

```bash
git clone <REPO-HTTPS-URL>
cd aws-cloud-lab
```

An initial attempt to clone the repository over SSH failed because the EC2 instance did not have the GitHub SSH credentials available on the local machine.

Because the repository is public, cloning over HTTPS avoided the need to copy GitHub credentials onto the instance.

The `uv` package manager was then installed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Running FastAPI

Uvicorn is the server responsible for running the FastAPI application.

Running:

```bash
uv run uvicorn main:app
```

binds Uvicorn to localhost by default.

`127.0.0.1` is the loopback interface, so an application listening only on `127.0.0.1` cannot accept connections through the EC2 instance's network interface.

To make the application reachable by other resources in the VPC, Uvicorn was started with:

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000
```

In this command:

- `main:app` loads the `app` object from `main.py`.
- `--host 0.0.0.0` listens on all available IPv4 interfaces.
- `--port 8000` listens on TCP port `8000`.

Binding Uvicorn to `0.0.0.0` does not make the application publicly accessible by itself. AWS networking and Security Groups still determine which sources are permitted to reach the instance.

Two separate conditions therefore have to be satisfied for another resource to reach the application:

1. Uvicorn must listen on an interface reachable by other resources.
2. The EC2 Security Group must permit the connection to the application port.

### Python Environment

Running `uvicorn` directly initially used a different Python environment and could not locate the FastAPI dependency.

Running Uvicorn through `uv`:

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000
```

ensured that it executed using the dependencies managed by the project environment.

The application could be tested locally from the EC2 instance with:

```bash
curl http://127.0.0.1:8000
curl http://127.0.0.1:8000/health
```

### Security Group Evolution

During early testing, the application EC2 instance was temporarily tested directly on port `8000`, with access restricted to the local public IP using a `/32` source.

In the final architecture:

```text
Internet
   |
   v
ALB Security Group
   |
 TCP :8000
   v
App Security Group
```

The application EC2 instance no longer has a public IP.

Instead of permitting port `8000` from the Internet, the App Security Group permits TCP `8000` from the ALB Security Group.

---

## Bastion Host

A bastion host was deployed in a public subnet to provide administrative access to the private application EC2 instance.

The SSH path is:

```text
Local Machine
     |
    SSH
     v
Bastion Public IP
     |
    SSH
     v
App Private IP
```

The Security Groups were configured so that:

- The Bastion Security Group permits SSH `22` from the local public IP using a `/32` source.
- The App Security Group permits SSH `22` from the Bastion Security Group.

### SSH ProxyJump

SSH `ProxyJump` was used so the private key could remain on the local machine instead of being copied to the bastion host.

Example `~/.ssh/config`:

```sshconfig
Host aws-bastion
    HostName <BASTION_PUBLIC_IP>
    User ec2-user
    IdentityFile ~/path/to/key.pem

Host aws-app
    HostName <APP_PRIVATE_IP>
    User ec2-user
    IdentityFile ~/path/to/key.pem
    ProxyJump aws-bastion
```

The private application instance could then be reached with:

```bash
ssh aws-app
```

### Troubleshooting

An initial `ssh -J` attempt failed because the jump-host SSH connection was not using the expected identity file.

Defining the bastion and application hosts explicitly in `~/.ssh/config` ensured that the correct identity file was used for each connection.

Another troubleshooting mistake involved attempting to reach a resource through its public IP while connecting through the bastion.

When using the bastion to reach resources inside the VPC, the destination resource's private IP address was used.

---

## NAT Instance

A NAT instance was deployed in a public subnet and assigned a public IP address to provide outbound Internet connectivity to the private application EC2 instance.

This allowed the application server to initiate outbound Internet connections without assigning the application server itself a public IP address.

The traffic path is:

```text
Private App EC2
      |
      v
Private Route Table
0.0.0.0/0 -> NAT Instance
      |
      v
Internet Gateway
      |
      v
Internet
```

### Source/Destination Check

EC2 normally expects traffic processed by an instance to have that instance as the source or destination.

A NAT instance intentionally forwards traffic belonging to other instances, so source/destination checking was disabled on the NAT instance.

### Linux Packet Forwarding

IPv4 forwarding was enabled:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

The setting was verified with:

```bash
sysctl net.ipv4.ip_forward
```

The instance's network interface was identified using:

```bash
ip route
```

`iptables` was then installed:

```bash
sudo dnf install iptables -y
```

### Network Address Translation

Outbound source NAT was configured using `MASQUERADE`:

```bash
sudo iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
```

Traffic originating from the private application subnet was permitted to be forwarded:

```bash
sudo iptables -A FORWARD -s 10.0.1.0/24 -j ACCEPT
```

Return traffic for established connections was permitted with:

```bash
sudo iptables -A FORWARD -d 10.0.1.0/24 \
  -m state --state ESTABLISHED,RELATED -j ACCEPT
```

The route table gets traffic **to** the NAT instance, `ip_forward` allows Linux to forward traffic **through** the instance, and `MASQUERADE` performs source NAT for outbound traffic.

### Troubleshooting

The private application EC2 instance initially could not reach the Internet.

The NAT Security Group had mistakenly been configured to allow traffic from:

```text
10.0.3.0/24
```

That CIDR belonged to one of the public subnets.

The private application subnet was actually:

```text
10.0.1.0/24
```

After correcting the NAT Security Group to permit traffic from the application subnet, outbound Internet connectivity succeeded.

Connectivity was validated with:

```bash
curl -I https://github.com
```

This failure demonstrated that a correct route alone is not enough. The complete traffic path—including routing, Security Groups, operating-system forwarding, and NAT configuration—must permit the connection.

---

## Application Load Balancer and Target Group

An Internet-facing Application Load Balancer was deployed across two public subnets in different Availability Zones.

The ALB provides the public entry point for the application while allowing the application EC2 instance to remain private.

The traffic path is:

```text
Internet
    |
 HTTP :80
    v
Application Load Balancer
    |
    v
Target Group
    |
 TCP :8000
    v
Private App EC2
    |
    v
Uvicorn / FastAPI
```

### Security Groups

The final Security Group relationship is:

```text
Internet
   |
 HTTP :80
   v
ALB-SG
   |
 TCP :8000
   v
App-SG
```

The ALB Security Group permits HTTP `80` from the Internet.

The App Security Group permits TCP `8000` from the ALB Security Group rather than permitting application traffic directly from the Internet.

### Health Check

The target group's health check was configured with:

```text
Protocol: HTTP
Path:     /health
Port:     traffic port (8000)
```

The FastAPI `/health` endpoint returns HTTP `200 OK` when the application is healthy.

Successful health checks appeared in the Uvicorn logs as:

```text
GET /health HTTP/1.1 200 OK
```

### Troubleshooting: Healthy Target but 504 Responses

The target initially showed as unhealthy because the health-check port configuration did not match the port used by FastAPI.

FastAPI was listening on TCP `8000`.

After configuring the health check to use port `8000`, Uvicorn began receiving successful health checks and the target became healthy.

However, normal requests through the ALB still returned:

```text
504 Gateway Time-out
```

The health check had been corrected, but the EC2 target itself was still registered on port `80`.

This resulted in two different traffic paths:

```text
Health Check
ALB -> EC2 :8000    ✓

Application Traffic
ALB -> EC2 :80      ✗
```

The EC2 target was deregistered from port `80` and registered on port `8000`.

The final configuration became:

```text
ALB Listener     :80
       |
       v
Target Group
       |
       v
EC2 Target       :8000
       |
       v
Uvicorn/FastAPI  :8000
```

The application was then validated through the ALB DNS endpoint:

```bash
curl http://<ALB-DNS>
```

Response:

```json
{ "message": "Hello Dudong" }
```

---

## Key Lessons

Phase 1 established several networking and infrastructure concepts that became the foundation for later phases:

- Public and private subnet behavior is determined by routing rather than subnet naming.
- Route tables determine where traffic is routed, while Security Groups determine whether that traffic is permitted.
- Security Groups are stateful, while Network ACLs are stateless.
- Private application instances do not require public IP addresses to serve Internet users when placed behind a public load balancer.
- Private instances can initiate Internet connections through a NAT device without accepting unsolicited inbound Internet connections.
- Application-level network binding and AWS-level network permissions are separate controls.
- Security Group references can restrict communication between infrastructure tiers without relying on broad CIDR-based access.
- A bastion host can provide administrative access without exposing private application instances directly to the Internet.
- SSH ProxyJump allows the SSH private key to remain on the local machine instead of being copied to an intermediate host.
- NAT instances require both AWS networking configuration and Linux forwarding/NAT configuration.
- ALB health-check traffic and normal target traffic must both use the correct application port.
- A healthy load balancer target does not necessarily prove that normal application traffic is configured correctly.

---

## Phase 1 Complete

By the end of Phase 1:

- FastAPI was running on a private EC2 instance with no public IP.
- Public HTTP traffic reached the application through the Application Load Balancer.
- ALB-to-application traffic was restricted using Security Groups.
- Administrative SSH access reached the application through the bastion host.
- The SSH private key remained on the local machine through ProxyJump.
- The application instance could initiate outbound Internet connections through the NAT instance.
- The `/health` endpoint successfully passed ALB health checks.
- End-to-end requests through the ALB successfully reached FastAPI.

The phase also provided hands-on troubleshooting experience across SSH, routing, NAT, Security Groups, ALB health checks, target ports, and application connectivity.
