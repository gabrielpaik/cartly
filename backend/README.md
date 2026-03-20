# WIMC backend scaffold

Commercial backend scaffold for WIMC.

## Planned stack
- FastAPI
- PostgreSQL
- NAS-backed AI worker/runtime

## Scope of this scaffold
- API entrypoint
- routers for auth / scan / carts / events / config
- pydantic schemas
- settings placeholder
- DB/session placeholder

## Current note
This is a scaffold only. Endpoints currently return placeholder responses and are meant to be filled against the docs in `../docs/`.

## Auth scaffold direction
- `POST /v1/auth/guest` stays separate for clean guest analytics
- `POST /v1/auth/login` is now provider-aware (`email | google | kakao`)
- app-side UI should call an auth abstraction so real SDK/backend exchange can be attached without redesigning the login screen
