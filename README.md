# 📚 Library Management System – DevOps CI/CD Demo Project

A containerized Library Management System with an automated local CI/CD pipeline. Built as a college DevOps project to demonstrate application development, automated testing, Docker containerization, and continuous deployment.

---

## Table of Contents

1. [Project Objective](#project-objective)
2. [Features](#features)
3. [Technology Stack](#technology-stack)
4. [Architecture Overview](#architecture-overview)
5. [CI vs CD in This Project](#ci-vs-cd-in-this-project)
6. [Prerequisites](#prerequisites)
7. [Quick Start](#quick-start)
8. [Running the Pipeline](#running-the-pipeline)
9. [Useful Commands Reference](#useful-commands-reference)
10. [Verify the Application](#verify-the-application)
11. [Demonstrate a Code Change and Redeployment](#demonstrate-a-code-change-and-redeployment)
12. [Demonstrate a Failed Test Preventing Deployment](#demonstrate-a-failed-test-preventing-deployment)
13. [Persistent Storage](#persistent-storage)
14. [Common Errors and Fixes](#common-errors-and-fixes)
15. [Viva Questions](#viva-questions)

---

## Project Objective

Demonstrate a complete DevOps workflow on a local machine:

1. **Develop** a web application (Flask + SQLite).
2. **Test** it automatically (pytest).
3. **Containerize** it (Docker).
4. **Deploy** it (Docker Compose).
5. **Automate** the entire process (PowerShell CI/CD pipeline).
6. **Inspect & troubleshoot** running containers.

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

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Host Machine (Windows)                │
│                                                         │
│   ┌──────────────────┐       ┌───────────────────────┐  │
│   │   pipeline.ps1   │       │    Docker Engine       │  │
│   │  (CI/CD Script)  │──────▶│                       │  │
│   │                  │       │  ┌───────────────────┐│  │
│   │ 1. Run Tests     │       │  │  library-app      ││  │
│   │ 2. Build Image   │       │  │  (Container)      ││  │
│   │ 3. Deploy        │       │  │                   ││  │
│   │ 4. Health Check  │       │  │  Flask App (:5000)││  │
│   └──────────────────┘       │  │       │           ││  │
│                              │  │       ▼           ││  │
│   ┌──────────────────┐       │  │  /data/library.db ││  │
│   │   Web Browser    │       │  └──────┬────────────┘│  │
│   │ localhost:5000   │◀──────│         │             │  │
│   └──────────────────┘       │  ┌──────▼────────────┐│  │
│                              │  │  library-data     ││  │
│                              │  │  (Docker Volume)  ││  │
│                              │  └───────────────────┘│  │
│                              └───────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Flow:**
1. Developer edits code locally.
2. Runs `pipeline.ps1`.
3. Pipeline runs tests → builds Docker image → deploys container → verifies health.
4. Application is accessible at `http://localhost:5000`.
5. SQLite database is stored in a Docker named volume (`library-data`), so data persists across deployments.

---

## CI vs CD in This Project

| Aspect | Continuous Integration (CI) | Continuous Deployment (CD) |
|---|---|---|
| **What it does** | Runs automated tests and builds the Docker image | Deploys the container and verifies it is healthy |
| **Pipeline stages** | Stages 2–3 (Test + Build) | Stages 4–6 (Deploy + Health Check) |
| **Goal** | Catch bugs before deployment | Deliver the working application automatically |
| **Trigger** | Running `pipeline.ps1` after a code change | Automatically follows CI if tests pass |

> **Honest note:** This is a *local* CI/CD demonstration using a PowerShell script. In production, teams use hosted CI platforms like GitHub Actions, GitLab CI, or Jenkins. The *concepts* (test → build → deploy → verify) are identical.

---

## Prerequisites

Install the following on your Windows laptop:

1. **Python 3.12+** → [python.org](https://www.python.org/downloads/)
   - ✅ Check "Add Python to PATH" during installation.
2. **Docker Desktop for Windows** → [docker.com](https://www.docker.com/products/docker-desktop/)
   - ✅ Ensure Docker Desktop is **running** before executing the pipeline.
3. **pip** (comes with Python).

Verify installations:

```powershell
python --version        # Should show Python 3.12.x
docker --version        # Should show Docker version ...
docker compose version  # Should show Docker Compose version ...
```

---

## Quick Start

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

## Running the Pipeline

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

## Demonstrate a Code Change and Redeployment

This shows the CI/CD pipeline rebuilding and redeploying after a code change.

### Step 1: Make a visible change

Open `templates/index.html` and change the heading:

```html
<!-- BEFORE -->
<h1>📚 Library Management System</h1>

<!-- AFTER -->
<h1>📚 Library Management System v2.0</h1>
```

### Step 2: Re-run the pipeline

```powershell
.\pipeline.ps1
```

### Step 3: Verify

Refresh `http://localhost:5000` in your browser. The heading should now show **"v2.0"**.

> **What happened:** The pipeline ran tests (ensuring nothing broke), rebuilt the Docker image with the new code, recreated the container, and verified it was healthy. Your book data is preserved because the database lives in a Docker volume, not inside the container.

---

## Demonstrate a Failed Test Preventing Deployment

This proves that the pipeline will **not deploy broken code**.

### Step 1: Break the health endpoint

Open `app.py` and change the health route:

```python
# BEFORE
return jsonify({"status": "healthy", "service": "library-management"}), 200

# AFTER (intentional bug)
return jsonify({"status": "healthy", "service": "library-management"}), 500
```

### Step 2: Run the pipeline

```powershell
.\pipeline.ps1
```

### Step 3: Observe

The pipeline will **stop at Stage 2** with a `[FAIL] Tests failed!` message. The Docker image will NOT be rebuilt and the running application will NOT be affected.

### Step 4: Revert the change

Undo the change (set it back to `200`) and re-run `.\pipeline.ps1`.

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

---

## Viva Questions

### 1. What is Docker and why did you use it?
Docker is a containerization platform that packages an application with all its dependencies into a standardized unit called a container. We used it to ensure the app runs consistently regardless of the host environment.

### 2. What is the difference between a Docker image and a container?
An **image** is a read-only template (like a class). A **container** is a running instance of an image (like an object). You build images and run containers.

### 3. What is Docker Compose?
Docker Compose is a tool for defining and running multi-container Docker applications using a YAML file. Even for single-container apps, it simplifies configuration of volumes, ports, and environment variables.

### 4. How does your CI/CD pipeline work?
The pipeline script (`pipeline.ps1`) automates six steps: (1) check the environment, (2) run automated tests, (3) build a Docker image, (4) deploy with Docker Compose, (5) wait for the app to become healthy, (6) verify the deployment with an HTTP health check. If any step fails, the pipeline stops immediately.

### 5. What is the difference between CI and CD?
**CI (Continuous Integration)** focuses on automatically testing and building code changes. **CD (Continuous Deployment)** automatically deploys the built artifact to a running environment. In our project, stages 2–3 are CI, and stages 4–6 are CD.

### 6. How does the database persist when the container is removed?
We use a Docker **named volume** (`library-data`). Volumes are managed by Docker and exist outside the container's filesystem. When a container is removed and recreated, the volume is reattached, preserving all data.

### 7. What is a health check and why is it important?
A health check is an endpoint (`/health`) that returns HTTP 200 when the application is functioning correctly. It allows Docker and our pipeline to automatically verify the app is working after deployment, enabling automated recovery and reliable deployments.

### 8. Why do tests use a separate database?
Tests use a temporary database created with `tempfile.mkstemp()` so that test data never corrupts the real application database. This isolation ensures tests are repeatable and independent.

### 9. What happens if a test fails in the pipeline?
The pipeline immediately stops at Stage 2 and exits with a non-zero exit code. The Docker image is NOT rebuilt and the running application is NOT affected. This prevents deploying broken code.

### 10. What is the `.dockerignore` file?
Similar to `.gitignore`, it tells Docker which files to exclude from the build context. This reduces image size and build time by not copying unnecessary files (tests, docs, local databases) into the image.

---

## Project Structure

```
library-management/
├── app.py                  # Flask application (routes, database logic)
├── requirements.txt        # Python dependencies
├── Dockerfile              # Docker image build instructions
├── docker-compose.yml      # Container orchestration configuration
├── .dockerignore           # Files excluded from Docker build
├── pipeline.ps1            # Automated CI/CD pipeline script
├── README.md               # This documentation
├── templates/
│   └── index.html          # HTML template (Jinja2)
├── static/
│   └── style.css           # Stylesheet
└── tests/
    └── test_app.py         # Automated test suite (pytest)
```
