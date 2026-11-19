"""Воркер: Redis Streams -> Playwright -> атомарная запись JSON -> XACK.

Гарантии:
- XACK только после успешной записи результата (at-least-once).
- Временный файл в том же каталоге + os.replace = атомарная запись.
- При старте переобрабатываем pending (XAUTOCLAIM) — после падения.
- Повторная доставка того же job_id перезаписывает тот же файл.
"""
import asyncio
import json
import logging
import os
import socket
import tempfile

import redis.asyncio as aioredis
from playwright.async_api import async_playwright

REDIS_URL = os.environ.get("REDIS_URL", "redis://redis:6379/0")
STREAM = os.environ.get("STREAM_NAME", "jobs")
GROUP = os.environ.get("GROUP_NAME", "scrapers")
CONSUMER = os.environ.get("CONSUMER_NAME", socket.gethostname())
RESULTS_DIR = os.environ.get("RESULTS_DIR", "/results")
BLOCK_MS = 5000
RETRY_IDLE_MS = 30000

log = logging.getLogger("worker")


async def scrape_quotes(url: str) -> list[dict]:
    """Скроллим /scroll, пока число цитат растёт, затем собираем их."""
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            args=["--no-sandbox", "--disable-dev-shm-usage"]
        )
        try:
            page = await browser.new_page()
            await page.goto(url, wait_until="domcontentloaded", timeout=60000)
            await page.wait_for_selector(".quote", timeout=30000)
            previous = -1
            while True:
                current = await page.locator(".quote").count()
                if current == previous:
                    break
                previous = current
                await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                await page.wait_for_timeout(600)
            return await page.eval_on_selector_all(
                ".quote",
                """els => els.map(el => ({
                    text: el.querySelector('.text')?.innerText ?? '',
                    author: el.querySelector('.author')?.innerText ?? '',
                    tags: Array.from(el.querySelectorAll('.tag')).map(t => t.innerText)
                }))""",
            )
        finally:
            await browser.close()


def write_result_atomic(job_id: str, payload: dict) -> None:
    os.makedirs(RESULTS_DIR, exist_ok=True)
    final_path = os.path.join(RESULTS_DIR, f"{job_id}.json")
    fd, tmp_path = tempfile.mkstemp(
        dir=RESULTS_DIR, prefix=f".{job_id}.", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
            f.flush()
            os.fsync(f.fileno())
        # mkstemp даёт 600, а Nginx (www-data) должен читать результат
        os.chmod(tmp_path, 0o644)
        os.replace(tmp_path, final_path)  # атомарно в пределах одной ФС
    except BaseException:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


async def ensure_group(r) -> None:
    try:
        # id="0": читаем и задания, добавленные до создания группы
        await r.xgroup_create(STREAM, GROUP, id="0", mkstream=True)
    except aioredis.ResponseError as e:
        if "BUSYGROUP" not in str(e):
            raise


async def process(r, msg_id: str, fields: dict, reclaimed: bool) -> None:
    job_id = fields.get("job_id")
    url = fields.get("url")
    if not job_id or not url:
        log.warning("Некорректное задание %s, отбрасываем: %s", msg_id, fields)
        await r.xack(STREAM, GROUP, msg_id)
        return
    # Инъекция отказа для fault-test: падаем после получения, до XACK,
    # только при первой доставке; при переобработке pending игнорируем.
    if fields.get("crash") == "1" and not reclaimed:
        log.warning("fault-test: падаем до XACK (job_id=%s)", job_id)
        os._exit(1)
    quotes = await scrape_quotes(url)
    payload = {"job_id": job_id, "url": url, "count": len(quotes), "quotes": quotes}
    write_result_atomic(job_id, payload)
    await r.xack(STREAM, GROUP, msg_id)  # XACK — последним, после записи
    log.info("job_id=%s готов: %d цитат", job_id, len(quotes))


async def reclaim_pending(r, min_idle_time: int = 0) -> None:
    """Забираем зависшие pending-сообщения (после падения воркера)."""
    cursor = "0-0"
    while True:
        cursor, messages, _deleted = await r.xautoclaim(
            STREAM, GROUP, CONSUMER,
            min_idle_time=min_idle_time, start_id=cursor, count=10,
        )
        for msg_id, fields in messages:
            await process(r, msg_id, fields, reclaimed=True)
        if cursor == "0-0":
            break


async def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    os.makedirs(RESULTS_DIR, exist_ok=True)
    r = aioredis.from_url(REDIS_URL, decode_responses=True)
    for _ in range(30):
        try:
            await r.ping()
            break
        except Exception:
            log.info("Ждём Redis...")
            await asyncio.sleep(1)
    else:
        raise SystemExit("Redis недоступен")
    await ensure_group(r)
    await reclaim_pending(r)
    log.info("Воркер %s готов (stream=%s, group=%s)", CONSUMER, STREAM, GROUP)
    while True:
        resp = await r.xreadgroup(GROUP, CONSUMER, {STREAM: ">"}, count=1, block=BLOCK_MS)
        if not resp:
            # нет новых заданий — дообрабатываем зависшие после ошибок
            await reclaim_pending(r, min_idle_time=RETRY_IDLE_MS)
            continue
        for _stream, messages in resp:
            for msg_id, fields in messages:
                try:
                    await process(r, msg_id, fields, reclaimed=False)
                except Exception:
                    # без XACK сообщение останется pending и переобработается
                    log.exception("Ошибка обработки %s", msg_id)


if __name__ == "__main__":
    asyncio.run(main())
