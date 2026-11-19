"""Продюсер: XADD одного задания в stream jobs. job_id печатается в stdout."""
import argparse
import os
import sys
import uuid

import redis


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("url")
    p.add_argument("--job-id", default=None)
    p.add_argument("--crash", action="store_true",
                   help="fault-test: воркер упадёт до XACK при первой доставке")
    args = p.parse_args()

    job_id = args.job_id or uuid.uuid4().hex[:12]
    r = redis.from_url(os.environ.get("REDIS_URL", "redis://redis:6379/0"),
                       decode_responses=True)
    fields = {"job_id": job_id, "url": args.url}
    if args.crash:
        fields["crash"] = "1"
    msg_id = r.xadd(os.environ.get("STREAM_NAME", "jobs"), fields)
    print(job_id)
    print(f"queued {msg_id}", file=sys.stderr)


if __name__ == "__main__":
    main()
