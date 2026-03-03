# reMIND API

Backend API server for the reMIND caregiver application. Built with NestJS, Kysely, and MSSQL.

## Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- [Docker](https://www.docker.com/products/docker-desktop/) (for the MSSQL database)

## Getting Started

### 1. Install dependencies

```bash
cd remind-api
npm install
```

### 2. Set up environment variables

Copy the example env file:

```bash
cp .env.example .env
```

The defaults work with the Docker database out of the box. For production, update `BETTER_AUTH_SECRET`.

### 3. Start the database

```bash
npm run docker:up
```

This starts a MSSQL Server 2022 container and runs the init script to create the `remind_db` database. The container exposes port `1433`.

Wait ~30 seconds for the database to fully initialize on first run.

### 4. Run database migrations

```bash
npm run db:migrate:kysely
```

### 5. Start the dev server

```bash
npm run start:dev
```

The API will be available at `http://localhost:3000`.

## API Endpoints

### Location

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/location` | Submit a patient location |
| GET | `/location/:patientId` | Get latest location for a patient |

### Safe Zones

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/safezones` | Create a safe zone |
| GET | `/safezones/:patientId` | Get all safe zones for a patient |
| PUT | `/safezones/:id` | Update a safe zone |
| DELETE | `/safezones/:id` | Delete a safe zone |

## Scripts

| Script | Description |
|--------|-------------|
| `npm run start:dev` | Start dev server with hot reload |
| `npm run start` | Start without hot reload |
| `npm run build` | Build for production |
| `npm run start:prod` | Run production build |
| `npm run db:migrate:kysely` | Run Kysely migrations (app tables) |
| `npm run docker:up` | Start MSSQL container |
| `npm run docker:down` | Stop MSSQL container |
| `npm run lint` | Lint and auto-fix |
| `npm run test` | Run tests |

## Stopping the database

```bash
npm run docker:down
```

Data persists in a Docker volume (`mssql_data`). To fully reset, remove the volume:

```bash
docker-compose down -v
```
