# Quick Cloud Computing Tutorial for Beginners

## Goal

By the end of this tutorial, you will understand the basic idea of cloud computing, have created an **Amazon S3 bucket**, uploaded a file into it, and loaded a CSV file from S3 into **Snowflake** using an external stage and the COPY INTO command.

---

## 1. What is Cloud Computing?

The simplest explanation:

> **Cloud computing means using someone else's computers over the internet instead of owning and managing the computers yourself.**

For example:

- Your laptop → your computer
- AWS → someone else's massive computers and data centers
- Instead of buying a server, you can rent computing and storage from AWS and pay for what you use.

### Traditional IT vs Cloud

| Traditional IT | Cloud |
|---|---|
| Buy a server | Rent computing |
| Buy hard drives | Rent storage |
| Manage the hardware | Cloud provider manages hardware |

The major cloud providers are:

- **AWS** — Amazon
- **Azure** — Microsoft
- **Google Cloud** — Google

---

## 2. What is Amazon S3?

**S3** stands for **Simple Storage Service**.

Think of S3 as:

> **Renting storage space in the cloud to store your files.**

Your computer might store a file like this:

```text
C:\Users\John\Documents\report.pdf
```

S3 stores files inside a **bucket**:

```text
AWS
└── S3
    └── my-bucket
        └── report.pdf
```

### Important terminology

**Bucket** = a container for your files.

```text
Bucket
│
├── photo.jpg
├── report.pdf
├── customers.csv
└── weather.json
```

**Object** = a file stored in S3.

Remember:

> **Bucket = container**
> **Object = file**

---

## 3. Sign in to AWS

Go to the AWS Management Console:

https://console.aws.amazon.com/

Sign in with your AWS account.

> **Important:** AWS is a paid cloud platform. Normal beginner use of S3 is inexpensive, but avoid creating large resources or uploading large amounts of data while learning. Check AWS pricing/free-tier information for your account.

---

## 4. Find S3

Once inside the AWS Console:

1. Use the search bar at the top.
2. Search for **S3**.
3. Select **S3 — Scalable Storage in the Cloud**.

You should arrive at the S3 dashboard.

---

# 5. Create Your First S3 Bucket

Click:

**Create bucket**

Think of this as creating your first cloud storage container.

### Bucket name

Enter a unique name, for example:

```text
my-first-s3-bucket-2026-abc123
```

S3 bucket names must be **globally unique**.

If someone else already has the name, AWS will not let you use it.

### AWS Region

Choose a region reasonably close to you.

For example, depending on availability:

- Canada (Calgary)
- Canada (Central)

For this beginner exercise, the exact region isn't critical.

### Object Ownership

Leave the default settings.

### Block Public Access

Keep:

**Block all public access**

enabled.

This is important because you don't want your beginner bucket accidentally exposed to the internet.

### Bucket Versioning

Leave the default setting.

### Encryption

Leave the default encryption settings.

Then click:

**Create bucket**

🎉 You now have your first cloud storage bucket.

---

# 6. Upload a File

Open the bucket you just created.

Click:

**Upload**

Then:

**Add files**

Create or select a simple file from your computer.

For example:

```text
hello.txt
```

Put this inside the file:

```text
Hello AWS!

This is my first file in the cloud.
```

Then:

1. Select `hello.txt`
2. Click **Upload**
3. Wait for the upload to complete.

AWS should show the upload as successful.

---

# 7. Understand What Just Happened

Your file started on your computer:

```text
Your Computer
     │
     │ Upload
     ▼
   AWS S3
     │
     ▼
   Bucket
     │
     ▼
 hello.txt
```

You have just performed a basic **cloud storage operation**.

---

# 8. Visualize the Architecture

Think about it like this:

```text
                 INTERNET
                     │
                     ▼
              ┌─────────────┐
              │     AWS     │
              │             │
              │     S3      │
              │      │      │
              │      ▼      │
              │  My Bucket  │
              │      │      │
              │      ▼      │
              │  hello.txt  │
              └─────────────┘
```

The key relationship is:

```text
AWS
└── S3
    └── Bucket
        └── Object (file)
```

---

# 9. S3 Is Not a Virtual Computer

This is an important distinction.

### S3

Used to **store files/data**.

### EC2

Used to provide a **virtual computer/server** where you can run applications.

### RDS

Used for **managed relational databases**.

### Lambda

Used to **run code without managing a server**.

A simple analogy:

```text
AWS
│
├── S3       → Warehouse 📦
│              Store your stuff
│
├── EC2      → Computer 💻
│              Run your programs
│
├── RDS      → Database 🗄️
│              Store structured data
│
└── Lambda   → Employee ⚙️
               Runs a task when needed
```

---

# 10. Beginner Challenge

Once you successfully upload `hello.txt`, try this exercise.

### Challenge

1. Create a folder called `data`
2. Create a file called `customers.csv`
3. Put 3–5 fake customer records in it.
4. Upload it into the `data` folder.
5. Open the file from S3.

You should end up with something like:

```text
my-first-s3-bucket
│
├── hello.txt
│
└── data/
    └── customers.csv
```

---

# 11. Connect S3 to Snowflake with an External Stage

Now that you have data in S3, the next step is to bring it into Snowflake. An **external stage** is a Snowflake object that points to your S3 bucket so you can load data from it.

### What is an External Stage?

> **An external stage is a named reference in Snowflake that points to a cloud storage location (like an S3 bucket) where your data files live.**

```text
S3 Bucket (customers.csv)
        │
        ▼
  External Stage (Snowflake)
        │
        ▼
  Snowflake Table
```

---

## 11a. Prepare Your CSV File

Make sure you have a simple CSV in your S3 bucket. For example, upload a file called `customers.csv` to your bucket (or inside a `data/` prefix):

```csv
id,first_name,last_name,email
1,Jane,Doe,jane.doe@example.com
2,John,Smith,john.smith@example.com
3,Alice,Johnson,alice.j@example.com
```

Your S3 path would look like:

```text
s3://my-first-s3-bucket-2026-abc123/data/customers.csv
```

---

## 11b. Create an IAM Policy and Role for Snowflake (AWS Side)

Before Snowflake can read from your bucket, you need to grant it access.

1. In the AWS Console, go to **IAM → Policies → Create policy**.
2. Use this JSON policy (replace the bucket name with yours):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::my-first-s3-bucket-2026-abc123",
        "arn:aws:s3:::my-first-s3-bucket-2026-abc123/*"
      ]
    }
  ]
}
```

3. Name the policy something like `snowflake-s3-read-access`.
4. Create an IAM Role with **Another AWS account** as the trusted entity. Use your own account ID for now (you will update the trust policy later with Snowflake's account details).
5. Attach the policy you created to this role.
6. Note the **Role ARN** — you will need it in the next step.

---

## 11c. Create a Storage Integration in Snowflake

A storage integration stores the IAM role information so Snowflake can authenticate to S3.

Run this in Snowflake (requires ACCOUNTADMIN):

```sql
CREATE OR REPLACE STORAGE INTEGRATION s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/your-snowflake-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://my-first-s3-bucket-2026-abc123/data/');
```

Then describe it to get Snowflake's AWS IAM user and external ID:

```sql
DESC INTEGRATION s3_integration;
```

Look for `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID` in the output. Go back to AWS and update your IAM role's trust policy to allow this Snowflake user to assume the role.

---

## 11d. Create the External Stage

Now create the stage that points to your S3 path:

```sql
CREATE OR REPLACE STAGE my_s3_stage
  STORAGE_INTEGRATION = s3_integration
  URL = 's3://my-first-s3-bucket-2026-abc123/data/'
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

IF YOU WANT TO CREATE DIRECTLY WITH CREDENTIALS

```sql
CREATE OR REPLACE STAGE my_s3_stage
  URL = 's3://your-bucket-name/weather/'
  CREDENTIALS = (
    AWS_KEY_ID = 'YOUR_AWS_ACCESS_KEY_ID' 
    AWS_SECRET_KEY = 'YOUR_AWS_SECRET_ACCESS_KEY'
  )

```
Verify you can see your file:

```sql
LIST @my_s3_stage;
```

You should see `customers.csv` in the output.

---

## 11e. Create a Target Table and COPY the Data

Create a table to receive the data:

```sql
CREATE OR REPLACE TABLE customers (
  id INT,
  first_name VARCHAR,
  last_name VARCHAR,
  email VARCHAR
);
```

Load the CSV into the table:

```sql
COPY INTO customers
  FROM @my_s3_stage/customers.csv
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

Verify the data loaded:

```sql
SELECT * FROM customers;
```

You should see your three customer rows.

---

## 11f. What Just Happened

```text
S3 Bucket
  └── data/
      └── customers.csv
              │
              │  COPY INTO
              ▼
Snowflake
  └── Database
      └── Schema
          └── CUSTOMERS table
              ├── 1, Jane, Doe, jane.doe@example.com
              ├── 2, John, Smith, john.smith@example.com
              └── 3, Alice, Johnson, alice.j@example.com
```

You connected cloud storage to a cloud data warehouse. This is a fundamental pattern in modern data engineering.

---

# 12. What You Should Know Now

Remember the key concepts:

**Cloud → AWS → S3 → Bucket → Object → Stage → Snowflake Table**

The full relationship:

```text
AWS
└── S3
    └── Bucket
        └── Object (file)
                │
          External Stage
                │
          COPY INTO
                │
          Snowflake Table
```

### Key Snowflake terms

| Term | Meaning |
|------|---------|
| Storage Integration | Stores cloud credentials securely in Snowflake |
| External Stage | A named pointer to a cloud storage location |
| FILE_FORMAT | Tells Snowflake how to parse your files (CSV, JSON, Parquet, etc.) |
| COPY INTO | The command that loads data from a stage into a table |
| LIST @stage | Shows files available in a stage |

### Final takeaway

> **Cloud computing is using computing resources over the internet. AWS is a cloud provider. S3 is AWS's object storage service. A bucket is a container, and an object is a file stored in that bucket. Snowflake connects to S3 via external stages, letting you load cloud-stored data into tables with COPY INTO.**

🎉 **Congratulations! You have created cloud infrastructure, stored data in S3, and loaded it into Snowflake.**
