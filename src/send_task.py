import os
import boto3

def main():
    endpoint = os.getenv("AWS_ENDPOINT_URL", "http://host.docker.internal:4566")
    queue_url = os.getenv("SQS_QUEUE_URL")
    
    if not queue_url:
        print("Ошибка: Не задана переменная окружения SQS_QUEUE_URL")
        exit(1)
    
    sqs = boto3.client(
        'sqs', endpoint_url=endpoint, region_name='us-east-1',
        aws_access_key_id='test', aws_secret_access_key='test'
    )
    
    sqs.send_message(QueueUrl=queue_url, MessageBody='{"action": "scrape"}')
    print("Задание успешно отправлено в SQS!")

if __name__ == "__main__":
    main()