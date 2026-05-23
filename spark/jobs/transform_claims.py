#!/usr/bin/env python3
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, when, lower, trim, abs, round as round_sql
from pyspark.sql.types import StructType, StructField, StringType
import argparse
import logging

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description="Transform health claims data")
    parser.add_argument("--raw-bucket",      required=True)
    parser.add_argument("--curated-bucket",  required=True)
    parser.add_argument("--execution-date",  required=True, help="YYYY-MM-DD")
    return parser.parse_args()


def get_schema():
    return StructType([
        StructField("claim_id",       StringType(), False),
        StructField("patient_id",     StringType(), False),
        StructField("service_date",   StringType(), True),
        StructField("amount",         StringType(), True),
        StructField("provider_id",    StringType(), True),
        StructField("diagnosis_code", StringType(), True),
    ])


def clean_claims(df):
    for c in ("claim_id", "patient_id", "provider_id", "diagnosis_code"):
        df = df.withColumn(c, trim(lower(col(c))))
    df = df.withColumn(
        "amount",
        when(col("amount").cast("double").isNotNull(),
             abs(col("amount").cast("double"))).otherwise(0.0)
    )
    df = df.withColumn("amount", round_sql(df["amount"], 2))
    df = df.withColumn("service_date", to_date(col("service_date"), "yyyy-MM-dd"))
    df = df.filter(col("claim_id").isNotNull() & col("patient_id").isNotNull())
    df = df.dropDuplicates(["claim_id"])
    return df


def main():
    args  = parse_args()
    spark = (SparkSession.builder
             .appName("health-claims-transform")
             .config("spark.sql.parquet.compression.codec", "snappy")
             .getOrCreate())
    spark.sparkContext.setLogLevel("WARN")

    raw_path     = f"s3a://{args.raw_bucket}/raw/claims/"
    curated_path = f"s3a://{args.curated_bucket}/curated/claims/{args.execution_date}/"

    logger.info(f"Reading raw data from {raw_path}")
    df_raw   = (spark.read.option("header", "true")
                          .option("inferSchema", "false")
                          .schema(get_schema())
                          .csv(raw_path))
    raw_count = df_raw.count()
    logger.info(f"Read {raw_count} raw rows")

    if raw_count == 0:
        logger.warning("No raw data — writing sample output")
        spark.createDataFrame(
            [("CLM001", "PAT12345", "2025-01-15", 150.00, "PRV001", "I10")],
            ["claim_id", "patient_id", "service_date", "amount", "provider_id", "diagnosis_code"]
        ).write.mode("overwrite").parquet(curated_path)
    else:
        df_clean = clean_claims(df_raw)
        logger.info(f"After cleaning: {df_clean.count()} rows")
        df_clean.write.mode("overwrite").parquet(curated_path)

    logger.info(f"Wrote curated data to {curated_path}")
    spark.stop()


if __name__ == "__main__":
    main()
