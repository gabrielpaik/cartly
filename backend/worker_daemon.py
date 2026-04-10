import argparse
import time
from datetime import datetime

from app.db.session import SessionLocal
from app.services.worker_service import process_next_job


def run_once():
    db = SessionLocal()
    try:
        job = process_next_job(db)
        if job is None:
            return None
        return {
            'id': job.id,
            'status': job.status,
            'errorCode': job.error_code,
        }
    finally:
        db.close()


def main():
    parser = argparse.ArgumentParser(description='WIMC scan worker daemon')
    parser.add_argument('--poll-interval', type=float, default=2.0)
    parser.add_argument('--post-job-sleep', type=float, default=0.2)
    parser.add_argument('--idle-log-seconds', type=float, default=60.0)
    args = parser.parse_args()

    last_idle_log_at = 0.0

    while True:
        job = run_once()
        now = time.time()

        if job is None:
            if now - last_idle_log_at >= args.idle_log_seconds:
                print(f"[{datetime.now().isoformat(timespec='seconds')}] idle:no-job", flush=True)
                last_idle_log_at = now
            time.sleep(max(args.poll_interval, 0.1))
            continue

        print(
            f"[{datetime.now().isoformat(timespec='seconds')}] processed:{job['id']}:{job['status']}:{job['errorCode'] or '-'}",
            flush=True,
        )
        time.sleep(max(args.post_job_sleep, 0.0))


if __name__ == '__main__':
    main()
