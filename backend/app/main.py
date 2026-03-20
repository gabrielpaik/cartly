from fastapi import FastAPI

from .routers import auth, carts, config, events, scan

app = FastAPI(title='WIMC API', version='0.1.0')

app.include_router(auth.router, prefix='/v1/auth', tags=['auth'])
app.include_router(scan.router, prefix='/v1/scan', tags=['scan'])
app.include_router(carts.router, prefix='/v1/carts', tags=['carts'])
app.include_router(events.router, prefix='/v1/events', tags=['events'])
app.include_router(config.router, prefix='/v1', tags=['config'])


@app.get('/health')
def health():
    return {
        'ok': True,
        'service': 'wimc-api',
        'storageRoot': '/Volumes/AI/WIMC',
    }
