import json
import os
import psycopg2
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):

    records = event.get("Records", [])
    if not records:
        logger.warning("No records in event")
        return {"status": "no_records"}

    for rec in records:
        bucket = rec["s3"]["bucket"]["name"]
        key    = rec["s3"]["object"]["key"]

        logger.info(f"New object uploaded: s3://{bucket}/{key}")

        # בעתיד: מפה היינו מוציאים מטא-דאטה, מפרקים את הקובץ,
        # ואז מכניסים לרשומה ב-DB.
        # כאן רק נדגים התחברות (ברמת הרעיון, לא חייב apply עכשיו):
        #
        # db_host = os.environ["DB_HOST"]
        # db_user = os.environ["DB_USER"]
        # db_pass = os.environ["DB_PASS"]
        # db_name = os.environ["DB_NAME"]
        #
        # conn = psycopg2.connect(
        #     host=db_host,
        #     user=db_user,
        #     password=db_pass,
        #     dbname=db_name,
        # )
        # cur = conn.cursor()
        # cur.execute(
        #     "INSERT INTO raw_ingest_log (bucket, object_key) VALUES (%s, %s);",
        #     (bucket, key)
        # )
        # conn.commit()
        # cur.close()
        # conn.close()

    return {"status": "ok", "processed": len(records)}

