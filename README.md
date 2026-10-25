# 📚 Library Management System – DevOps CI/CD Demo Project

A containerized Library Management System with both a local PowerShell CI/CD pipeline **and a GitHub Actions CI/CD pipeline**. Built as a college DevOps project to demonstrate application development, automated testing, Docker containerization, container registry publishing, and continuous deployment.

---

## Table of Contents

1. [Project Objective](#project-objective)
2. [Features](#features)
3. [Technology Stack](#technology-stack)
4. [Architecture Overview](#architecture-overview)
5. [CI vs CD vs Continuous Delivery](#ci-vs-cd-vs-continuous-delivery)
6. [Prerequisites](#prerequisites)
7. [Quick Start (Local Pipeline)](#quick-start-local-pipeline)
8. [Running the Local Pipeline](#running-the-local-pipeline)
9. [GitHub Actions CI/CD Pipeline](#github-actions-cicd-pipeline)
10. [GHCR – GitHub Container Registry](#ghcr--github-container-registry)
11. [Deploying from GHCR Locally](#deploying-from-ghcr-locally)
12. [Environment Variables & Secrets](#environment-variables--secrets)
13. [Creating & Verifying a Pull Request](#creating--verifying-a-pull-request)
14. [Demonstrate a Failed Test Blocking the Pipeline](#demonstrate-a-failed-test-blocking-the-pipeline)
15. [Useful Commands Reference](#useful-commands-reference)
16. [Persistent Storage](#persistent-storage)
17. [Security](#security)
18. [Common Errors and Fixes](#common-errors-and-fixes)
19. [Viva Questions](#viva-questions)
20. [Project Structure](#project-structure)

---

## Project Objective

Demonstrate a complete DevOps workflow:

1. **Develop** a web application (Flask + SQLite).
2. **Test** it automatically (pytest).
3. **Containerize** it (Docker).
4. **Automate CI/CD** with two methods:
   - **Local pipeline** → PowerShell script (`pipeline.ps1`)
   - **Cloud pipeline** → GitHub Actions (`.github/workflows/ci.yml`)
5. **Publish** Docker images to GitHub Container Registry (GHCR).
6. **Deploy** locally by pulling the published image.
7. **Scan** for container vulnerabilities (Trivy).
8. **Inspect & troubleshoot** running containers.

---

## Features

- View all books in the library.
- Add a book (title, author, ISBN) with validation.
- Delete a book.
- Prevent duplicate ISBNs.
- Empty-library message when no books exist.
- `/health` endpoint for monitoring.
- Sample books seeded on first run.
- Persistent database across container restarts.

---

## Technology Stack

| Technology | Purpose |
|---|---|
| **Python 3.12** | Application programming language |
| **Flask** | Lightweight web framework for building the HTTP server and routes |
| **SQLite** | Embedded relational database – no separate database server needed |
| **pytest** | Automated testing framework for Python |
| **Docker** | Containerization – packages the app with all dependencies into an image |
| **Docker Compose** | Multi-container orchestration – defines and runs the app as a service |
| **PowerShell** | Local CI/CD pipeline automation script |
| **GitHub Actions** | Cloud-based CI/CD – runs tests and publishes Docker images on every push |
| **GHCR** | GitHub Container Registry – stores published Docker images |
| **Trivy** | Container vulnerability scanner |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       GitHub (Cloud)                             │
│                                                                 │
│   ┌─────────────────────────────────────────────────────┐       │
│   │            GitHub Actions Workflow                   │       │
│   │                                                     │       │
│   │  ┌──────────┐   ┌──────────────┐   ┌───────────┐   │       │
│   │  │  🧪 Test │──▶│ 🐳 Build &   │──▶│ 🔍 Trivy  │   │       │
│   │  │  (pytest)│   │  Push (GHCR) │   │   Scan    │   │       │
│   │  └──────────┘   └──────┬───────┘   └───────────┘   │       │
│   └─────────────────────────┼───────────────────────────┘       │
│                             │                                   │
│                    ┌────────▼────────┐                           │
│                    │  GHCR Registry  │                           │
│                    │  (Docker Image) │                           │
│                    └────────┬────────┘                           │
└─────────────────────────────┼───────────────────────────────────┘
                              │  docker pull
┌─────────────────────────────┼───────────────────────────────────┐
│                Host Machine (Windows)                            │
│                             │                                   │
│   ┌──────────────────┐      │     ┌───────────────────────┐     │
│   │   deploy.ps1     │──────┘     │    Docker Engine       │    │
│   │  (or pipeline.ps1│───────────▶│                       │    │
│   │   for local dev) │            │  ┌───────────────────┐│    │
│   └──────────────────┘            │  │  library-app      ││    │
│                                   │  │  (Container)      ││    │
│   ┌──────────────────┐            │  │                   ││    │
│   │   Web Browser    │            │  │  Flask App (:5000)││    │
│   │ localhost:5000   │◀───────────│  │       │           ││    │
│   └──────────────────┘            │  │       ▼           ││    │
│                                   │  │  /data/library.db ││    │
│                                   │  └──────┬────────────┘│    │
│                                   │  ┌──────▼────────────┐│    │
│                                   │  │  library-data     ││    │
│                                   │  │  (Docker Volume)  ││    │
│                                   │  └───────────────────┘│    │
│                                   └───────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## CI vs CD vs Continuous Delivery

These three terms are often confused. Here is what each one means:

| Term | Definition | In This Project |
|---|---|---|
| **Continuous Integration (CI)** | Automatically run tests and build artifacts whenever code is pushed. The goal is to catch bugs early. | The GitHub Actions workflow runs pytest and builds a Docker image on every push. |
| **Continuous Delivery** | Automatically prepare a release artifact that *could* be deployed, but a human decides when to deploy. | The Docker image is published to GHCR. You manually run `deploy.ps1` to deploy it. |
| **Continuous Deployment** | Automatically deploy every change that passes tests – no human approval needed. | We do NOT do this, because GitHub's cloud runners cannot access your laptop's Docker. |

> **Why not full continuous deployment?**
> A GitHub-hosted runner is a temporary virtual machine in Microsoft's cloud. It has no network access to your laptop's Docker daemon. To achieve true continuous deployment, you would need a server with a public IP address running Docker, or a self-hosted GitHub Actions runner on your machine. For a college project, continuous delivery (CI + GHCR publish + manual local deploy) is the practical and honest approach.

### Local Pipeline vs GitHub Actions

| Aspect | `pipeline.ps1` (Local) | GitHub Actions (Cloud) |
|---|---|---|
| **Where it runs** | Your Windows laptop | GitHub's Ubuntu servers |
| **Trigger** | You run it manually | Automatic on push/PR |
| **Tests** | pytest on your machine | pytest on GitHub's runner |
| **Docker build** | Builds locally | Builds on GitHub's runner |
| **Publishes image?** | No (local only) | Yes, to GHCR |
| **Deploys?** | Yes, via Docker Compose | No (use `deploy.ps1` locally) |
| **Best for** | Quick local development | Team collaboration, PR reviews |

---

## Prerequisites

Install the following on your Windows laptop:

1. **Python 3.12+** → [python.org](https://www.python.org/downloads/)
   - ✅ Check "Add Python to PATH" during installation.
2. **Docker Desktop for Windows** → [docker.com](https://www.docker.com/products/docker-desktop/)
   - ✅ Ensure Docker Desktop is **running** before executing the pipeline.
3. **Git** → [git-scm.com](https://git-scm.com/downloads/)
4. **pip** (comes with Python).

Verify installations:

```powershell
python --version        # Should show Python 3.12.x
docker --version        # Should show Docker version ...
docker compose version  # Should show Docker Compose version ...
git --version           # Should show git version ...
```

---

## Quick Start (Local Pipeline)

```powershell
# 1. Open PowerShell and navigate to the project
cd "C:\Users\hp\OneDrive\Desktop\Library management system"

# 2. Run the full CI/CD pipeline
.\pipeline.ps1

# 3. Open in browser
Start-Process "http://localhost:5000"
```

That's it! The pipeline tests, builds, deploys, and verifies everything automatically.

---

## Running the Local Pipeline

```powershell
.\pipeline.ps1
```

The pipeline executes 7 stages:

| Stage | Action | On Failure |
|---|---|---|
| 1 | Environment check (Python, Docker) | Stops with error |
| 2 | Run pytest suite | **Stops – no deployment** |
| 3 | Build Docker image | Stops with error |
| 4 | Deploy with Docker Compose | Stops with error |
| 5 | Wait for healthy status (up to 60s) | Stops with timeout |
| 6 | Post-deployment HTTP health check | Stops with error |
| 7 | Print success summary | – |

---

## GitHub Actions CI/CD Pipeline

### What is GitHub Actions?

GitHub Actions is a CI/CD platform built into GitHub. You define workflows in YAML files inside `.github/workflows/`. GitHub automatically runs these workflows on its own servers (called **runners**) whenever the configured events occur (push, PR, etc.).

### Workflow File

The workflow is defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

### Triggers

The workflow runs automatically when:
- You **push** to `main` or any `feature/**` branch
- You open a **pull request** targeting `main`

### Jobs and Stages

The workflow has 3 jobs that run in sequence:

```
┌──────────┐     ┌───────────────────┐     ┌─────────────────┐
│  🧪 Test │────▶│ 🐳 Build & Push   │────▶│ 🔍 Trivy Scan   │
│          │     │  (main only)      │     │  (main only)    │
└──────────┘     └───────────────────┘     └─────────────────┘
```

| Job | What it does | Runs on | Condition |
|---|---|---|---|
| **test** | Checks out code, sets up Python 3.12, installs dependencies, runs `pytest` | Every push and PR | Always |
| **build-and-push** | Builds Docker image and pushes to GHCR with SHA + `latest` tags | Only after `test` passes | Only on pushes to `main` |
| **scan** | Runs Trivy vulnerability scanner on the published image | Only after `build-and-push` succeeds | Only on pushes to `main` |

### How to Find Workflow Results

1. Go to your repository on GitHub: `https://github.com/Shams102/Library-management-system`
2. Click the **"Actions"** tab at the top
3. You'll see a list of workflow runs with ✅ (passed) or ❌ (failed) icons
4. Click on any run to see the details of each job and step
5. Expand any step to see its logs (like test output or Docker build output)

### Key GitHub Actions Concepts

| Concept | Explanation |
|---|---|
| **Workflow** | A YAML file that defines automation. Lives in `.github/workflows/`. |
| **Job** | A set of steps that run on the same runner. Jobs can depend on each other. |
| **Step** | A single task within a job (e.g., "run pytest", "build Docker image"). |
| **Runner** | The server that runs your workflow. `ubuntu-latest` = GitHub's free Ubuntu VM. |
| **Action** | A reusable plugin (e.g., `actions/checkout@v4` checks out your code). |
| **`needs`** | Makes one job depend on another. `needs: test` means "run only after test passes". |
| **`if`** | Conditional execution. `if: github.ref == 'refs/heads/main'` means "only on main". |
| **`GITHUB_TOKEN`** | A built-in secret that GitHub automatically provides. Used to authenticate with GHCR. |
| **Permissions** | Controls what the `GITHUB_TOKEN` can do. We use `packages: write` to push to GHCR. |

---

## GHCR – GitHub Container Registry

### What is GHCR?

GitHub Container Registry (GHCR) is a place to store Docker images, similar to Docker Hub but integrated with GitHub. Your images live at `ghcr.io/YOUR-USERNAME/YOUR-REPO`.

### How Images Are Published

When you push code to `main` and tests pass, the GitHub Actions workflow automatically:
1. Logs in to GHCR using the built-in `GITHUB_TOKEN`
2. Builds the Docker image
3. Tags it with:
   - `sha-<full-commit-hash>` (e.g., `sha-dc4405b...`) – uniquely identifies the exact code version
   - `latest` – always points to the most recent successful build
4. Pushes both tags to `ghcr.io/shams102/library-management-system`

### How to Find Your Image on GitHub

1. Go to `https://github.com/Shams102/Library-management-system`
2. Look for **"Packages"** on the right sidebar
3. Click on the package name to see all available tags
4. Or go directly to: `https://github.com/Shams102/Library-management-system/pkgs/container/library-management-system`

### How to Pull the Image

```powershell
# Pull the latest version
docker pull ghcr.io/shams102/library-management-system:latest

# Pull a specific commit version
docker pull ghcr.io/shams102/library-management-system:sha-dc4405b...
```

> **Note:** If the image is private, you need to authenticate first:
> ```powershell
> # Log in to GHCR (use a GitHub PAT with read:packages scope)
> echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
> ```

### First-Time Setup: Make Your Package Public (Optional)

By default, GHCR packages may be private. To make pulling easier:
1. Go to `https://github.com/Shams102/Library-management-system/pkgs/container/library-management-system`
2. Click **"Package settings"** (gear icon)
3. Scroll to **"Danger Zone"** → **"Change package visibility"** → Select **"Public"**

---

## Deploying from GHCR Locally

After the GitHub Actions workflow publishes your image to GHCR, you can deploy it on your laptop:

### Using the Deploy Script

```powershell
# Deploy the latest image
.\deploy.ps1

# Deploy a specific version
.\deploy.ps1 -Tag "sha-dc4405b..."
```

The deploy script:
1. Authenticates with GHCR
2. Pulls the specified image
3. Recreates the container with Docker Compose
4. Waits for the app to become healthy
5. Verifies the deployment

### Authentication for GHCR Pull

The deploy script needs a GitHub Personal Access Token (PAT) to pull from GHCR:

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Click **"Generate new token (classic)"**
3. Give it a name like "GHCR Pull"
4. Select the **`read:packages`** scope
5. Click **"Generate token"** and copy the token
6. Set it as an environment variable:

```powershell
$env:GHCR_TOKEN = "ghp_your_token_here"
.\deploy.ps1
```

Or the script will prompt you to enter it.

### Manual Deployment (without the script)

```powershell
# 1. Log in to GHCR
echo "ghp_your_token" | docker login ghcr.io -u shams102 --password-stdin

# 2. Pull the image
docker pull ghcr.io/shams102/library-management-system:latest

# 3. Deploy (use only docker-compose.yml, not the override, so it pulls instead of building)
$env:IMAGE_NAME = "ghcr.io/shams102/library-management-system"
$env:IMAGE_TAG = "latest"
docker compose -f docker-compose.yml up -d --force-recreate --no-build

# 4. Verify
Start-Process "http://localhost:5000"
```

---

## Environment Variables & Secrets

### Required Variables

| Variable | Purpose | Where to Set |
|---|---|---|
| `SECRET_KEY` | Flask session signing key | `.env` file (never commit!) |
| `IMAGE_TAG` | Docker image tag to deploy | Set by `deploy.ps1` or `.env` |
| `IMAGE_NAME` | Docker image name (for GHCR deployment) | Set by `deploy.ps1` |
| `GHCR_TOKEN` | GitHub PAT for pulling images | Environment variable |

### Setup

```powershell
# Create your .env file from the template
copy .env.example .env

# Edit .env and set a real SECRET_KEY
notepad .env
```

### GitHub Secrets (Automatic)

The GitHub Actions workflow uses `GITHUB_TOKEN`, which is **automatically provided by GitHub** – you do NOT need to configure it. It has the necessary `packages: write` permission declared in the workflow file.

---

## Creating & Verifying a Pull Request

This is how you demonstrate the CI workflow in action:

### Step 1: Create a feature branch (already done)

```powershell
# You're already on feature/ci-cd-pipeline
git branch
```

### Step 2: Commit and push your changes

```powershell
git add -A
git commit -m "Add GitHub Actions CI/CD pipeline with GHCR publishing"
git push -u origin feature/ci-cd-pipeline
```

### Step 3: Create a Pull Request on GitHub

1. Go to `https://github.com/Shams102/Library-management-system`
2. You'll see a yellow banner saying "feature/ci-cd-pipeline had recent pushes" → click **"Compare & pull request"**
3. Title: `Add GitHub Actions CI/CD pipeline`
4. Click **"Create pull request"**

### Step 4: Watch the CI run

1. On the PR page, scroll down to see the **status checks**
2. Click **"Details"** next to the check to see the workflow
3. Wait for the ✅ green checkmark (tests passed!)
4. Note: Only the `test` job runs on PRs. The `build-and-push` job only runs after merging to `main`.

### Step 5: Merge the PR

1. Click **"Merge pull request"** → **"Confirm merge"**
2. Go to the **Actions** tab to see the full workflow (test → build-and-push → scan) running on `main`

---

## Demonstrate a Failed Test Blocking the Pipeline

This proves that broken code cannot be published or deployed.

### Step 1: Break the health endpoint

Open `app.py` and change the health route:

```python
# BEFORE
return jsonify({"status": "healthy", "service": "library-management"}), 200

# AFTER (intentional bug)
return jsonify({"status": "healthy", "service": "library-management"}), 500
```

### Step 2: Commit and push

```powershell
git add app.py
git commit -m "Intentionally break health endpoint for demo"
git push
```

### Step 3: Observe

- Go to the **Actions** tab on GitHub
- The `🧪 Run Tests` job will **fail** with a red ❌
- The `🐳 Build & Push Docker Image` job will **not run at all** (it depends on the test job)
- No broken image is published to GHCR

### Step 4: Also test locally

```powershell
.\pipeline.ps1
```

The pipeline will **stop at Stage 2** with `[FAIL] Tests failed!`. No Docker image is built.

### Step 5: Revert the change

```powershell
# Undo the change
git checkout -- app.py
git commit --allow-empty -m "Revert: fix health endpoint"
git push
```

---

## Useful Commands Reference

### Run Tests Locally (without Docker)

```powershell
# Install dependencies
pip install -r requirements.txt

# Run all tests with verbose output
python -m pytest tests/ -v
```
> **What this does:** Runs the automated test suite against a temporary in-memory database. No Docker needed.

### Build the Docker Image Manually

```powershell
docker build -t library-management:v1 .
```
> **What this does:** Reads the `Dockerfile` and creates a container image tagged `library-management:v1`.

### Start the Application

```powershell
docker compose up -d
```
> **What this does:** Starts the application container in the background (`-d` = detached mode).

### Stop the Application

```powershell
docker compose down
```
> **What this does:** Stops and removes the container. The database volume is **preserved**.

### Full Cleanup (stops app + removes image)

```powershell
docker compose down
docker rmi library-management:v1
```
> ⚠️ This removes the image. The database volume is still preserved.

### Nuclear Cleanup (removes everything including data)

```powershell
docker compose down -v
docker rmi library-management:v1
```
> ⚠️ The `-v` flag removes the named volume, **deleting all book data**.

### Inspect the Running Container

```powershell
# List running containers
docker ps

# Detailed container info
docker inspect library-app

# Check container health status
docker inspect --format="{{.State.Health.Status}}" library-app
```

### Inspect the Docker Image

```powershell
# List images
docker images

# Image build history (layers)
docker history library-management:v1
```

### View Application Logs

```powershell
# View all logs
docker compose logs

# Follow logs in real time
docker compose logs -f

# View last 50 lines
docker compose logs --tail=50
```

### Open a Shell Inside the Container

```powershell
docker exec -it library-app /bin/bash
```
> **What this does:** Opens an interactive terminal inside the running container for debugging.

---

## Verify the Application

1. Open your browser and go to: **http://localhost:5000**
2. You should see the Library Management System with 3 sample books.
3. Try adding a new book.
4. Try deleting a book.
5. Visit **http://localhost:5000/health** – you should see:
   ```json
   {"service": "library-management", "status": "healthy"}
   ```

---

## Persistent Storage

| Concept | Explanation |
|---|---|
| **Docker Volume** | A `library-data` named volume is defined in `docker-compose.yml` |
| **Mount Point** | The volume is mounted at `/data` inside the container |
| **Database Path** | SQLite database is stored at `/data/library.db` |
| **Persistence** | Data survives: container stops, container removal, image rebuilds, pipeline re-runs |
| **Data loss** | Data is only lost if you explicitly delete the volume with `docker compose down -v` |

### Verify Persistence

```powershell
# 1. Add a book via the web UI
# 2. Stop and remove the container
docker compose down

# 3. Start it again
docker compose up -d

# 4. Refresh the browser – your book is still there!
```

---

## Security

### Secret Management

- The `SECRET_KEY` is **not hardcoded** in `docker-compose.yml`. It is read from the `.env` file or environment variables.
- The `.env` file is listed in both `.gitignore` and `.dockerignore` so it is never committed or included in the Docker image.
- A `.env.example` file is provided as a template.
- The GitHub Actions workflow uses `GITHUB_TOKEN` which is automatically managed by GitHub.

### Trivy Vulnerability Scan

The pipeline includes a Trivy security scan that runs after the image is published to GHCR.

**What it scans:** The Docker image's operating system packages and Python dependencies for known security vulnerabilities (CVEs).

**What it reports:** CRITICAL and HIGH severity vulnerabilities that have fixes available.

**Does it block the pipeline?** No – it is set to `exit-code: "0"` (informational only). This is intentional because:
- Base image vulnerabilities are often outside your control
- Blocking on every CVE would make the pipeline unusable for a student project
- The scan still **surfaces** issues so you can investigate them

> **Honest note:** A vulnerability scan does NOT make the application "secure." It checks for *known* vulnerabilities in dependencies. Application-level security (SQL injection, XSS, authentication) requires separate measures.

---

## Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `docker: command not found` | Docker not installed or not in PATH | Install Docker Desktop and restart PowerShell |
| `error during connect` | Docker Desktop is not running | Start Docker Desktop and wait for it to be ready |
| `port 5000 already in use` | Another app is using port 5000 | Stop the other app, or change the port in `docker-compose.yml` |
| `pip: command not found` | Python not in PATH | Reinstall Python with "Add to PATH" checked |
| `ModuleNotFoundError: flask` | Dependencies not installed | Run `pip install -r requirements.txt` |
| `PermissionError` on pipeline | PowerShell execution policy | Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Tests pass but deploy fails | Docker build context issue | Check `.dockerignore` and ensure `Dockerfile` is correct |
| GitHub Actions workflow not running | Workflow file not on `main` | Merge your feature branch to `main` first |
| GHCR push fails with 403 | Package permissions not set | Go to repo Settings → Actions → General → set "Read and write permissions" |
| `denied: installation not allowed` | GITHUB_TOKEN lacks permissions | Ensure `packages: write` is in the workflow permissions |
| `deploy.ps1` authentication fails | Bad GHCR token | Generate a new PAT with `read:packages` scope |

---

## Viva Questions

### 1. What is Docker and why did you use it?
Docker is a containerization platform that packages an application with all its dependencies into a standardized unit called a container. We used it to ensure the app runs consistently regardless of the host environment.

### 2. What is the difference between a Docker image and a container?
An **image** is a read-only template (like a class). A **container** is a running instance of an image (like an object). You build images and run containers.

### 3. What is Docker Compose?
Docker Compose is a tool for defining and running multi-container Docker applications using a YAML file. Even for single-container apps, it simplifies configuration of volumes, ports, and environment variables.

### 4. How does your local CI/CD pipeline work?
The pipeline script (`pipeline.ps1`) automates six steps: (1) check the environment, (2) run automated tests, (3) build a Docker image, (4) deploy with Docker Compose, (5) wait for the app to become healthy, (6) verify the deployment with an HTTP health check. If any step fails, the pipeline stops immediately.

### 5. What is the difference between CI, continuous delivery, and continuous deployment?
**CI (Continuous Integration)** automatically tests and builds code on every push. **Continuous Delivery** automatically prepares a release artifact (like a Docker image on GHCR) but requires a human to trigger deployment. **Continuous Deployment** automatically deploys every successful build without human intervention. Our project implements CI + Continuous Delivery.

### 6. What is GitHub Actions and how does your workflow work?
GitHub Actions is a CI/CD platform built into GitHub. Our workflow (`.github/workflows/ci.yml`) has three jobs: (1) **test** – runs pytest on every push/PR, (2) **build-and-push** – builds a Docker image and pushes it to GHCR (only on `main`, only after tests pass), (3) **scan** – runs Trivy vulnerability scanner. Jobs are chained using `needs:` so a test failure blocks everything downstream.

### 7. What is GHCR and how do you publish to it?
GHCR (GitHub Container Registry) is a Docker image registry hosted by GitHub. Our workflow logs in using the built-in `GITHUB_TOKEN`, builds the image, tags it with the Git commit SHA and `latest`, and pushes it. No personal access token is needed for publishing because `GITHUB_TOKEN` with `packages: write` permission is sufficient.

### 8. How do you ensure a failed test prevents deployment?
In GitHub Actions, the `build-and-push` job has `needs: test`. If the `test` job fails, `build-and-push` is skipped entirely – no image is built or published. Locally, `pipeline.ps1` checks `$LASTEXITCODE` after pytest and exits with code 1 if tests fail, preventing all subsequent stages.

### 9. Why can't GitHub Actions deploy to your laptop?
A GitHub Actions runner is a temporary virtual machine in Microsoft's cloud. It has no network access to my laptop's Docker daemon. To deploy locally, I pull the published image from GHCR using `deploy.ps1`. True continuous deployment to my laptop would require a self-hosted runner or a server with a public IP.

### 10. What is a Docker volume and how does data persist?
A Docker **named volume** (`library-data`) is managed by Docker and exists outside the container's filesystem. When a container is removed and recreated, the volume is reattached, preserving all data. Data is only lost if you explicitly delete the volume with `docker compose down -v`.

### 11. What is `GITHUB_TOKEN`?
`GITHUB_TOKEN` is a short-lived access token that GitHub automatically creates for every workflow run. It has permissions scoped to the repository and expires when the workflow finishes. We use it to authenticate with GHCR – no manual secret setup is needed.

### 12. What does the Trivy scan check?
Trivy scans the Docker image for known security vulnerabilities (CVEs) in OS packages and Python dependencies. It reports CRITICAL and HIGH severity issues. In our setup, it's informational (doesn't block the pipeline) because base image vulnerabilities are often outside our control.

### 13. What is the `docker-compose.override.yml` file?
Docker Compose automatically loads `docker-compose.override.yml` alongside `docker-compose.yml` when you run `docker compose up` without specifying `-f`. Our override file adds the `build:` directive for local development. When deploying from GHCR, `deploy.ps1` explicitly specifies only `docker-compose.yml`, so it pulls the pre-built image instead of rebuilding.

### 14. How do you handle secrets in this project?
`SECRET_KEY` is read from a `.env` file that is excluded from Git (via `.gitignore`) and Docker builds (via `.dockerignore`). A `.env.example` template is provided. In GitHub Actions, `GITHUB_TOKEN` is automatically managed. No real secrets are ever hardcoded or committed.

### 15. What is the difference between `pipeline.ps1` and `deploy.ps1`?
`pipeline.ps1` is the local CI/CD pipeline – it runs tests, builds the Docker image locally, and deploys it. `deploy.ps1` pulls a pre-built image from GHCR and deploys it without running tests or building locally. Use `pipeline.ps1` for development, `deploy.ps1` for deploying the published image.

### 16. How does the health check work?
The `/health` endpoint returns `{"status": "healthy"}` with HTTP 200. Docker checks this endpoint every 30 seconds. If it fails 3 times in a row, Docker marks the container as unhealthy. Both `pipeline.ps1` and `deploy.ps1` verify the health endpoint after deployment.

---

## Project Structure

```
library-management/
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions CI/CD workflow
├── app.py                      # Flask application (routes, database logic)
├── requirements.txt            # Python dependencies
├── Dockerfile                  # Docker image build instructions
├── docker-compose.yml          # Container orchestration configuration
├── docker-compose.override.yml # Local dev override (adds build directive)
├── .dockerignore               # Files excluded from Docker build
├── .gitignore                  # Files excluded from Git
├── .env.example                # Template for environment variables
├── pipeline.ps1                # Local CI/CD pipeline script
├── deploy.ps1                  # GHCR deployment script
├── README.md                   # This documentation
├── templates/
│   └── index.html              # HTML template (Jinja2)
├── static/
│   └── style.css               # Stylesheet
└── tests/
    └── test_app.py             # Automated test suite (pytest)
```
