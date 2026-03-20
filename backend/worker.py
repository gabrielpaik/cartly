from app.db.session import SessionLocal
from app.services.worker_service import process_next_job


def main():
    db = SessionLocal()
    try:
        job = process_next_job(db)
        if job is None:
            print('no-job')
        else:
            print(f'processed:{job.id}:{job.status}')
    finally:
        db.close()


if __name__ == '__main__':
    main()
