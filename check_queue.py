import boto3
import os

endpoint = "http://localhost:4566"
queue_url = "http://localhost:4566/000000000000/scraper-tasks-queue"

sqs = boto3.client(
    'sqs', 
    endpoint_url=endpoint, 
    region_name='us-east-1',
    aws_access_key_id='test', 
    aws_secret_access_key='test'
)

attrs = sqs.get_queue_attributes(
    QueueUrl=queue_url, 
    AttributeNames=['ApproximateNumberOfMessages']
)

count = attrs['Attributes']['ApproximateNumberOfMessages']
print(f"✅ Сообщений в очереди: {count}")

if count == "0":
    print("🎉 Отлично! Все задания обработаны и удалены!")
else:
    print(f"⚠️ В очереди ещё {count} необработанных заданий.")