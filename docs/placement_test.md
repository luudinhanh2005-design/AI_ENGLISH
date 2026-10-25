# Placement Test (CEFR adaptive v2)

## Overview

The placement flow is a multi-stage adaptive assessment aligned to CEFR A1-C2.
It covers five skills:

- Listening
- Reading
- Use of English
- Writing
- Speaking

## Modes

- `quick`: 2 stages, 3 receptive skills, 24 items, about 20 minutes
- `standard`: 3 stages, 3 receptive skills + 1 writing task, about 55 minutes
- `full`: 3 stages, 3 receptive skills + 2 writing tasks + 3 speaking tasks, about 85 minutes

## Backend API

- `GET /api/v1/placement/config`
- `POST /api/v1/placement/sessions`
- `GET /api/v1/placement/sessions/{id}`
- `POST /api/v1/placement/sessions/{id}/answers`
- `POST /api/v1/placement/sessions/{id}/stages/complete`
- `POST /api/v1/placement/sessions/{id}/writing`
- `POST /api/v1/placement/sessions/{id}/speaking`
- `POST /api/v1/placement/sessions/{id}/speaking/skip`
- `GET /api/v1/placement/results/latest`
- `GET /api/v1/placement/results/{id}`
- `GET /api/v1/placement/history`

Legacy `/placement/questions` and `/placement/submit` return `410 Gone`.

## Scoring

Receptive items use 3PL IRT. Skill and overall theta are estimated with EAP.
CEFR cut scores:

- A1: theta < -1.50
- A2: theta < -0.75
- B1: theta < 0.00
- B2: theta < 0.75
- C1: theta < 1.50
- C2: theta >= 1.50

Writing and speaking are graded with CEFR rubrics by AI, with deterministic
local fallbacks. Results include CEFR level, confidence range, exam reference
equivalents, strengths, weaknesses, roadmap and can-do descriptors.

## Flutter flow

`/placement` opens `PlacementTestScreen`, which shows mode selection, resumes an
in-progress session, runs receptive/listening/reading/grammar stages, collects
writing and speaking responses, and displays `PlacementResultScreen`.
