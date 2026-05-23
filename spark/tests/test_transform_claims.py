"""Unit tests for transform_claims.py"""
import pytest
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..","jobs"))
from transform_claims import clean_claims, get_schema


@pytest.fixture(scope="session")
def spark():
    return (SparkSession.builder
            .master("local[1]")
            .appName("test-health-claims")
            .getOrCreate())


def test_clean_claims_removes_duplicates(spark):
    df = spark.createDataFrame([
        ("CLM001", "PAT001", "2025-01-01", "150.00", "PRV001", "I10"),
        ("CLM001", "PAT001", "2025-01-01", "150.00", "PRV001", "I10"),
    ], ["claim_id", "patient_id", "service_date", "amount", "provider_id", "diagnosis_code"])
    result = clean_claims(df)
    assert result.count() == 1


def test_clean_claims_drops_null_claim_id(spark):
    df = spark.createDataFrame([
        (None,     "PAT001", "2025-01-01", "100.00", "PRV001", "I10"),
        ("CLM002", "PAT002", "2025-01-02",  "50.00", "PRV002", "J45"),
    ], ["claim_id", "patient_id", "service_date", "amount", "provider_id", "diagnosis_code"])
    result = clean_claims(df)
    assert result.count() == 1


def test_clean_claims_normalizes_amount(spark):
    df = spark.createDataFrame([
        ("CLM003", "PAT003", "2025-01-03", "-200.505", "PRV003", "E11"),
    ], ["claim_id", "patient_id", "service_date", "amount", "provider_id", "diagnosis_code"])
    result = clean_claims(df)
    row = result.collect()[0]
    assert row["amount"] == 200.51


def test_clean_claims_lowercases_ids(spark):
    df = spark.createDataFrame([
        ("CLM004", "PAT004", "2025-01-04", "75.00", "PRV004", "A09"),
    ], ["claim_id", "patient_id", "service_date", "amount", "provider_id", "diagnosis_code"])
    result = clean_claims(df)
    row = result.collect()[0]
    assert row["claim_id"] == "clm004"
