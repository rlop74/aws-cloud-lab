from fastapi import FastAPI, HTTPException
import os
from dotenv import load_dotenv
import psycopg

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Hello Dudong"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/db-health")
def db_health():
    try:
        with psycopg.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=3
        ) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT version()")
                db_version=cur.fetchone()
                print(db_version)
                return {"db_status":"healthy"}
    except psycopg.Error as e:
        print(e)
        raise HTTPException(
            status_code=503,
            detail="Database unavailable"
      )
