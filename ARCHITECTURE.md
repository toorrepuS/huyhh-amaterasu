# HR Analytics Database Architecture - Lakehouse with Medallion Architecture

## Overview

This document presents the database architecture for building an HR Analytics system using the Lakehouse model with Medallion Architecture. This architecture is designed to process data from multiple sources and provide powerful analytics capabilities for human resource decision-making.

## Architecture Overview Diagram

```mermaid
graph TB
    subgraph "Data Sources"
        A[HRIS System]
        B[Performance Mgmt]
        C[Recruitment System]
        D[Time & Attendance]
        E[LMS]
        F[Manual Files]
    end

    subgraph "Bronze Layer - Raw Data"
        G[(Hadoop HDFS<br/>Parquet/JSON/CSV)]
    end

    subgraph "Silver Layer - Cleansed Data"
        H[(Delta Lake<br/>PySpark Processing)]
    end

    subgraph "Gold Layer - Business Data"
        I[(PostgreSQL<br/>Star Schema)]
    end

    subgraph "BI & Analytics"
        J[Apache Superset / Metabase]
        K[Dashboards]
        L[Reports]
    end

    A --> G
    B --> G
    C --> G
    D --> G
    E --> G
    F --> G

    G --> H
    H --> I
    I --> J
    J --> K
    J --> L

    style G fill:#CD853F
    style H fill:#88929b
    style I fill:#c1b100
    style J fill:#16af44
```

## Medallion Architecture Flow

```mermaid
flowchart LR
    subgraph "Bronze Layer"
        B1[Raw Data<br/>Landing Zone]
        B2[No Schema<br/>Validation]
        B3[Exact Copy<br/>of Source]
    end

    subgraph "Silver Layer"
        S1[Data Cleaning]
        S2[Schema Enforcement]
        S3[Business Rules]
        S4[SCD Type 2]
    end

    subgraph "Gold Layer"
        G1[Aggregations]
        G2[Star Schema]
        G3[Business KPIs]
        G4[Optimized Queries]
    end

    subgraph "Consumption"
        C1[BI Tools]
        C2[ML Models]
        C3[APIs]
    end

    B1 --> S1
    B2 --> S2
    B3 --> S3
    S1 --> G1
    S2 --> G2
    S3 --> G3
    S4 --> G4
    G1 --> C1
    G2 --> C2
    G3 --> C3

    style B1 fill:#CD853F
    style S1 fill:#88929b
    style G1 fill:#c1b100
    style C1 fill:#16af44
```

## 1. Architecture Overview

### 1.1. Lakehouse Model
Lakehouse combines the advantages of Data Lake (flexible storage) and Data Warehouse (high query performance), enabling:
- Storage of structured and unstructured data
- Batch and streaming processing
- Support for machine learning and analytics
- Metadata management and schema evolution

### 1.2. Medallion Architecture
The architecture divides data into 3 main layers:
- **Bronze**: Raw Data
- **Silver**: Cleansed Data
- **Gold**: Aggregated Data

## 2. Data Sources

### 2.1. Data Sources Diagram

```mermaid
mindmap
  root((HR Data Sources))
    Core Systems
      HRIS
        Employee Info
        Payroll
        Benefits
      Performance Mgmt
        KPIs
        Reviews
        Goals
      Time & Attendance
        Clock In/Out
        Leave Requests
        Overtime
    External Systems
      Recruitment
        Job Postings
        Applications
        Interviews
      Learning Mgmt
        Training Records
        Certifications
        Skills
    Manual Sources
      Excel Files
      CSV Exports
      Survey Data
```

### 2.2. Source Systems
- **HRIS (Human Resource Information System)**: Employee information, payroll, benefits
- **Performance Management System**: Performance evaluations, KPIs, objectives
- **Recruitment System**: Recruitment data, candidates, interview processes
- **Time & Attendance System**: Time tracking, leave requests, overtime
- **Learning Management System**: Training, certifications, skills
- **Manual Files**: Excel, CSV from departments

### 2.3. Data Characteristics
- **Update Frequency**: Daily, weekly, monthly
- **Format**: JSON, CSV, XML, Database dumps
- **Volume**: From few MB to few GB per day
- **Quality**: May contain missing, duplicate, inconsistent data

## 3. Bronze Layer - Raw Data Layer

### 3.1. Purpose
Store exact, unchanged copies of source data to ensure:
- Audit and traceability capabilities
- Reprocessing capabilities when needed
- Complete historical storage

### 3.2. Technology Stack
```
Storage: Hadoop HDFS / Amazon S3 / Azure Blob Storage
Format: Parquet, JSON, CSV (giữ nguyên format gốc)
Partitioning: Theo ngày, tháng, nguồn dữ liệu
```

### 3.3. Directory Structure
```
/bronze/
├── hris/
│   ├── year=2024/month=01/day=15/
│   └── year=2024/month=01/day=16/
├── performance/
├── recruitment/
├── attendance/
└── manual_files/
```

### 3.4. Ingestion Process
- **Batch Processing**: Scheduled jobs (daily, weekly)
- **Real-time**: Kafka/Event streaming for critical data
- **Manual Upload**: Interface for Excel/CSV files
- **API Integration**: REST/SOAP APIs from source systems

## 4. Silver Layer - Cleansed Data Layer

### 4.1. Purpose
Clean, standardize and consolidate data from Bronze layer:
- Data quality improvement
- Schema standardization
- Data deduplication
- Business rule application

### 4.2. Technology Stack
```
Processing Engine: Apache Spark (PySpark)
Storage Format: Delta Lake / Apache Iceberg
Data Quality: Great Expectations / Deequ
Data Governance: OpenLineage / DataHub
Orchestration: Apache Airflow
```

### 4.3. Processing Workflow

#### 4.3.1. Data Cleaning
```python
# Example PySpark code
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

# Clean employee data
df_employees = spark.read.parquet("/bronze/hris/employees/")
df_clean = df_employees \
    .filter(col("employee_id").isNotNull()) \
    .withColumn("email", lower(trim(col("email")))) \
    .withColumn("phone", regexp_replace(col("phone"), "[^0-9]", "")) \
    .dropDuplicates(["employee_id"])
```

#### 4.3.2. Data Standardization
- Date format standardization
- Code mapping (department codes, job titles)
- Currency conversion
- Address standardization

#### 4.3.3. Slowly Changing Dimensions (SCD Type 2)
```python
# Handle SCD Type 2 for employee information
def apply_scd_type2(current_df, new_df, key_cols, track_cols):
    # Logic to track changes over time
    # Add effective_date, end_date, is_current
    pass
```

## 5. Gold Layer - Presentation Layer

### 5.1. Purpose
Create optimized data models for reporting and analytics:
- Pre-aggregated metrics
- Star schema optimization
- Business-ready datasets
- High-performance queries

### 5.2. Technology Stack
```
Processing: PySpark (aggregation)
Serving Database: PostgreSQL
Schema: Star Schema / Snowflake Schema
Indexing: B-tree, Bitmap indexes
```

### 5.3. Star Schema Design
``` See README.md for reference ```

## 6. Business Intelligence

**Tools**: Apache Superset or Metabase

**Main Dashboards**:

### Executive Reports
- Employee headcount over time
- Turnover rates
- HR costs

### HR Reports
- Recruitment funnel
- Time to hire
- Performance distribution

### Manager Reports
- Team performance
- Employee attendance
- Development plans

**Key Metrics**:
- Turnover rate
- Training hours
- Performance scores
- Internal promotion rate

## 7. Security and Governance

**Data Quality**:
- Automated checks at each layer
- Data error alerts
- Data lineage tracking

**Security**:
- Role-based access control
- Sensitive data encryption
- Access logging

**Compliance**:
- GDPR (right to be forgotten)
- Local labor laws
- Data retention policies

## 8. Data Governance and Security

### 8.1. Data Quality Framework
- **Validation Rules**: Automated checks at each layer
- **Monitoring**: Data quality metrics and alerting
- **Lineage Tracking**: Data source tracking
- **Documentation**: Metadata management

### 8.2. Security Measures
- **Access Control**: Role-based access (RBAC)
- **Data Masking**: PII protection in non-prod environments
- **Encryption**: At rest and in transit
- **Audit Logging**: Tracking data access and modifications

### 8.3. Compliance
- **GDPR**: Right to be forgotten, data portability
- **Local Regulations**: Compliance with local labor laws
- **Data Retention**: Policies for data storage and deletion

## 9. Implementation Roadmap

### Implementation Timeline

```mermaid
gantt
    title HR Analytics Implementation Roadmap
    dateFormat  YYYY-MM-DD
    section Phase 1: Foundation
    Setup Infrastructure    :p1-1, 2024-01-01, 30d
    Bronze Layer Setup      :p1-2, after p1-1, 30d
    Data Quality Framework  :p1-3, after p1-2, 15d

    section Phase 2: Processing
    Silver Layer Development :p2-1, after p1-3, 45d
    SCD Type 2 Implementation :p2-2, after p2-1, 30d
    Airflow Orchestration    :p2-3, after p2-2, 15d

    section Phase 3: Analytics
    Gold Layer Design        :p3-1, after p2-3, 30d
    PostgreSQL Setup         :p3-2, after p3-1, 15d
    Initial Dashboards       :p3-3, after p3-2, 30d

    section Phase 4: Enhancement
    Advanced Analytics       :p4-1, after p3-3, 30d
    ML Models               :p4-2, after p4-1, 30d
    Self-service BI         :p4-3, after p4-2, 15d
```

## 10. Monitoring and Maintenance

### 10.1. Operational Monitoring
- **Data Pipeline Health**: Success rates, execution times
- **Data Quality Metrics**: Completeness, accuracy, consistency
- **System Performance**: Resource utilization, query performance

### 10.2. Business Monitoring
- **Usage Analytics**: Dashboard views, report downloads
- **User Feedback**: Satisfaction surveys, feature requests
- **Business Impact**: Decision-making improvements

## 11. Technology Stack Overview

```mermaid
graph TB
    subgraph "Data Ingestion"
        A1[Apache Kafka]
        A2[Apache Airflow]
        A3[Custom APIs]
    end

    subgraph "Storage Layer"
        B1[Hadoop HDFS]
        B2[Delta Lake]
        B3[PostgreSQL]
    end

    subgraph "Processing Layer"
        C1[Apache Spark]
        C2[PySpark]
        C3[SQL Engines]
    end

    subgraph "Analytics Layer"
        D1[Apache Superset]
        D2[Jupyter Notebooks]
        D3[REST APIs]
    end

    subgraph "Monitoring"
        E1[Prometheus]
        E2[Grafana]
        E3[Data Quality Tools]
    end

    A1 --> B1
    A2 --> B1
    A3 --> B1
    B1 --> C1
    B2 --> C2
    C1 --> B3
    C2 --> B3
    B3 --> D1
    B3 --> D2
    B3 --> D3

    style B1 fill:#CD853F
    style B2 fill:#88929b
    style B3 fill:#c1b100
    style D1 fill:#16af44

```

## 12. Conclusion

The Lakehouse with Medallion architecture for HR Analytics provides:
- **Scalability**: Handle large volumes of data
- **Flexibility**: Support multiple data types and use cases
- **Reliability**: Good data quality and governance
- **Performance**: Fast queries for analytics
- **Cost-effectiveness**: Optimized storage and compute costs

This architecture ensures organizations can make data-driven HR decisions effectively and reliably.
