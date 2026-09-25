FROM python:3.12-slim-trixie

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates

# download and install uv
ADD https://astral.sh/uv/install.sh /uv-installer.sh

# run and remove downloaded uv installer
RUN sh /uv-installer.sh && rm /uv-installer.sh

# ensure command is in PATH
ENV PATH="/root/.local/bin/:$PATH"

# set application directory
WORKDIR /app

# copy pyproject.toml and uv.lock to app folder
COPY pyproject.toml uv.lock ./

# sync only the dependencies and not the project itself
RUN uv sync --no-install-project

# copy application source
COPY . .

# start FastAPI when the container runs
CMD ["/app/.venv/bin/uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
