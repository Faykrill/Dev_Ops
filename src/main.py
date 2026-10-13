import asyncio
import json
import os
import boto3
from playwright.async_api import async_playwright

AWS_ENDPOINT = os.getenv("AWS_ENDPOINT_URL", "http://host.docker.internal:4566")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")

if not SQS_QUEUE_URL or not S3_BUCKET_NAME:
    print("Ошибка: Не заданы переменные окружения SQS_QUEUE_URL или S3_BUCKET_NAME")
    exit(1)

sqs = boto3.client(
    'sqs', endpoint_url=AWS_ENDPOINT, region_name='us-east-1',
    aws_access_key_id='test', aws_secret_access_key='test'
)
s3 = boto3.client(
    's3', endpoint_url=AWS_ENDPOINT, region_name='us-east-1',
    aws_access_key_id='test', aws_secret_access_key='test'
)

async def scrape_quotes():
    print("Запуск браузера...")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        
        await page.goto("https://quotes.toscrape.com/scroll", wait_until="domcontentloaded")
        await page.wait_for_selector(".quote")
        
        await page.evaluate("""async () => {
            await new Promise(resolve => {
                let totalHeight = 0;
                const timer = setInterval(() => {
                    window.scrollBy(0, 200);
                    totalHeight += 200;
                    if (totalHeight >= 600) { clearInterval(timer); resolve(); }
                }, 100);
            });
        }""")
        await asyncio.sleep(1)

        quotes = await page.evaluate("""() => {
            return Array.from(document.querySelectorAll('.quote')).map(el => ({
                text: el.querySelector('.text')?.innerText || '',
                author: el.querySelector('.author')?.innerText || ''
            }));
        }""")
        await browser.close()
        return quotes

async def main():
    print(f"Скрапер запущен. Ожидание сообщений из: {SQS_QUEUE_URL}")
    while True:
        response = sqs.receive_message(QueueUrl=SQS_QUEUE_URL, MaxNumberOfMessages=1, WaitTimeSeconds=10)
        messages = response.get('Messages', [])
        
        if not messages:
            continue
            
        message = messages[0]
        receipt_handle = message['ReceiptHandle']
        print(f"Получено задание: {message['Body']}")
        
        try:
            # 1. Скрапинг
            quotes = await scrape_quotes()
            result_json = json.dumps(quotes, indent=2, ensure_ascii=False)
            
            # 2. Сохранение в S3
            s3.put_object(Bucket=S3_BUCKET_NAME, Key='result.json', Body=result_json, ContentType='application/json')
            print(f"Успешно сохранено {len(quotes)} цитат в S3 bucket: {S3_BUCKET_NAME}")
            
            # 3. Удаление из SQS ТОЛЬКО после успешной записи
            sqs.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=receipt_handle)
            print("Сообщение удалено из очереди SQS.")
            
        except Exception as e:
            print(f"Ошибка при обработке задания: {e}")
            print("Сообщение НЕ удалено и будет доступно повторно.")

if __name__ == "__main__":
    asyncio.run(main())