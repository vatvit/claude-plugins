---
title: Implement user authentication
status: in-progress
type: feature
priority: high
epic: user-management
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | done | JWT auth, register/login/logout |
| 20 | BDD | skipped | |
| 30 | Assessment | done | No existing auth module |
| 40 | POC | skipped | Standard JWT pattern |
| 50 | Domain | — | |
| 60 | Architecture | done | See below |
| 70 | Tests | in-progress | |
| 80 | Subtasks | skipped | Small enough |
| 90 | Implementation | in-progress | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

Add JWT-based authentication. Users can register, login, logout.

## Architecture

- Users table with email, password_hash
- JWT tokens with 24h expiry
- Auth middleware for protected routes
- Using bcrypt for password hashing

## Implementation Progress

- [x] Create users table
- [x] Implement registration
- [x] Implement login with JWT
- [ ] Add auth middleware
- [ ] Write tests
