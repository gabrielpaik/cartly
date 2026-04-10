# Cartly auth provider flow

## Why this change

Commercial auth should keep the UI stable while provider implementation evolves.

That means:
- the login screen should describe provider value clearly
- the app should call an auth abstraction instead of creating sessions directly in UI code
- the stored session should remember which provider created it
- backend auth payloads should already be provider-aware even if the current implementation is still placeholder-level

## Frontend shape

### Provider buttons kept
- Kakao = Korea-first conversion entry
- Google = default trust + multi-device portability
- Email = backup / work account path
- Guest = lowest-friction browse path

### Flow boundary
The login page should only decide **which path the user chose**.
It should not know placeholder emails or provider-specific session details.

`LoginPage -> AuthStore -> AuthRepository`

That keeps real SDK integration cleaner later:
- current `RemoteAuthRepository` for backend token exchange
- future provider SDK wrappers behind the same boundary
- the UI/auth store boundary stays stable even as provider implementation changes

## Backend scaffold direction

`POST /v1/auth/login` should accept `provider` now, even if the first real implementation still only fully supports email.

Recommended commercial behavior later:
- `email`: lightweight email login / magic-link / OTP
- `google`: provider token exchange -> Cartly session token
- `kakao`: provider token exchange -> Cartly session token
- `guest`: separate guest endpoint still OK for analytics clarity

## Product notes

### CMO view
- lead with Kakao in Korea for conversion
- keep Google visible for trust and future global reach
- do not bury guest; it protects top-of-funnel activation

### CDO view
- show account value in plain language: saved carts, scan history, personalized perks
- avoid a "settings-looking" auth screen; it should feel like progress toward value
- minimize future rewrites by keeping provider metadata in session state
