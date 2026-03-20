# WIMC API spec draft v1

Base assumption:
- App-facing backend API
- DB is source of truth
- NAS `/Volumes/AI/WIMC` is storage/runtime infrastructure behind the API

## Common rules

### Base URL
Example:
- `https://api.wimc.app`
- local/dev example: `http://192.168.x.x:8000`

### Auth
- MVP commercial version should use bearer token auth for signed-in users
- guest session should also receive a session token

Header:
```http
Authorization: Bearer <token>
```

### Standard envelope
Success:
```json
{
  "ok": true,
  "data": {}
}
```

Error:
```json
{
  "ok": false,
  "error": {
    "code": "INVALID_INPUT",
    "message": "잘못된 요청이에요"
  }
}
```

---

## 1. Auth

### POST /v1/auth/guest
Create guest session.

Request:
```json
{
  "deviceId": "device_abc123",
  "platform": "ios",
  "appVersion": "0.1.0"
}
```

Response:
```json
{
  "ok": true,
  "data": {
    "user": {
      "id": "usr_guest_001",
      "displayName": "Guest",
      "email": null,
      "isGuest": true
    },
    "session": {
      "token": "guest_token_here",
      "expiresAt": "2026-03-27T12:00:00Z"
    }
  }
}
```

### POST /v1/auth/login
Provider-aware login entrypoint.
The commercial shape should keep one exchange endpoint and pass provider metadata through it.

Request:
```json
{
  "email": "user@example.com",
  "displayName": "Seungdae",
  "provider": "email",
  "deviceId": "device_abc123"
}
```

`provider` enum:
- `email`
- `google`
- `kakao`

For social providers, the next implementation step is token exchange while keeping this provider-aware payload shape.


Response:
```json
{
  "ok": true,
  "data": {
    "user": {
      "id": "usr_001",
      "displayName": "Seungdae",
      "email": "user@example.com",
      "isGuest": false
    },
    "session": {
      "token": "jwt_or_session_token",
      "expiresAt": "2026-03-27T12:00:00Z"
    }
  }
}
```

### POST /v1/auth/logout
Invalidate session.

Response:
```json
{
  "ok": true,
  "data": {
    "loggedOut": true
  }
}
```

### GET /v1/auth/me
Get current session user.

Response:
```json
{
  "ok": true,
  "data": {
    "user": {
      "id": "usr_001",
      "displayName": "Seungdae",
      "email": "user@example.com",
      "isGuest": false
    }
  }
}
```

---

## 2. Scan jobs

### POST /v1/scan/jobs
Upload image and create scan job.

Content-Type:
- `multipart/form-data`

Fields:
- `image` (file, required)
- `deviceId` (string, optional)
- `clientTimestamp` (string, optional)

Response:
```json
{
  "ok": true,
  "data": {
    "job": {
      "id": "job_001",
      "status": "queued",
      "createdAt": "2026-03-20T13:00:00Z"
    }
  }
}
```

### GET /v1/scan/jobs/{jobId}
Get job status.

Response:
```json
{
  "ok": true,
  "data": {
    "job": {
      "id": "job_001",
      "status": "processing",
      "errorCode": null,
      "errorMessage": null,
      "createdAt": "2026-03-20T13:00:00Z",
      "updatedAt": "2026-03-20T13:00:03Z"
    }
  }
}
```

Status enum:
- `queued`
- `uploading`
- `processing`
- `done`
- `failed`

### GET /v1/scan/jobs/{jobId}/result
Get normalized OCR/AI result.

Response:
```json
{
  "ok": true,
  "data": {
    "jobId": "job_001",
    "status": "done",
    "result": {
      "name": "커클랜드 키친타올",
      "price": 18990,
      "sku": "123456",
      "confidence": 0.82,
      "source": "nas-ai",
      "rawText": "..."
    }
  }
}
```

### POST /v1/scan/jobs/{jobId}/feedback
Store user correction result for training/analytics.

Request:
```json
{
  "accepted": false,
  "original": {
    "name": "커클랜드 키친",
    "price": 1890
  },
  "corrected": {
    "name": "커클랜드 키친타올",
    "price": 18990
  }
}
```

Response:
```json
{
  "ok": true,
  "data": {
    "saved": true
  }
}
```

---

## 3. Carts

### GET /v1/carts
List carts for current user.

Response:
```json
{
  "ok": true,
  "data": {
    "carts": [
      {
        "id": "cart_001",
        "title": null,
        "totalPrice": 32980,
        "totalCount": 3,
        "createdAt": "2026-03-20T13:00:00Z",
        "updatedAt": "2026-03-20T13:05:00Z"
      }
    ]
  }
}
```

### POST /v1/carts
Create a cart.

Request:
```json
{
  "title": null,
  "items": [
    {
      "name": "커클랜드 키친타올",
      "price": 18990,
      "quantity": 1,
      "scanResultId": "scan_result_001"
    }
  ]
}
```

Response:
```json
{
  "ok": true,
  "data": {
    "cart": {
      "id": "cart_001"
    }
  }
}
```

### GET /v1/carts/{cartId}
Get one cart.

### PATCH /v1/carts/{cartId}
Update cart metadata or items.

### DELETE /v1/carts/{cartId}
Soft-delete or archive cart.

---

## 4. Events

### POST /v1/events
Generic event ingestion endpoint.

Request:
```json
{
  "events": [
    {
      "name": "scan_started",
      "screen": "home",
      "props": {
        "source": "camera"
      },
      "clientTimestamp": "2026-03-20T13:00:00Z"
    },
    {
      "name": "ad_impression",
      "screen": "scan_result",
      "props": {
        "slotKey": "result_inline_1"
      },
      "clientTimestamp": "2026-03-20T13:00:03Z"
    }
  ]
}
```

Response:
```json
{
  "ok": true,
  "data": {
    "accepted": 2
  }
}
```

---

## 5. Ads / config

### GET /v1/app-config
Client bootstrap config.

Response:
```json
{
  "ok": true,
  "data": {
    "features": {
      "remoteScan": true,
      "adsEnabled": true
    },
    "adSlots": [
      {
        "slotKey": "result_inline_1",
        "placementType": "inline",
        "enabled": true,
        "config": {
          "maxHeight": 96
        }
      }
    ]
  }
}
```

---

## Core error codes

Auth:
- `UNAUTHORIZED`
- `SESSION_EXPIRED`

Scan:
- `UPLOAD_FAILED`
- `JOB_NOT_FOUND`
- `OCR_TIMEOUT`
- `OCR_NOT_CONFIDENT`
- `RESULT_NOT_READY`

Cart:
- `CART_NOT_FOUND`
- `INVALID_CART_ITEM`

Events:
- `INVALID_EVENT_PAYLOAD`

Generic:
- `INVALID_INPUT`
- `INTERNAL_ERROR`

---

## Notes for implementation

- App should start with `guest` or `login` and receive a token either way.
- Scan jobs should be DB-tracked, not file-path-tracked in the app.
- Feedback endpoint is important for OCR improvement and should be included early.
- Ad configuration should come from server so slot strategy can evolve without app release.
