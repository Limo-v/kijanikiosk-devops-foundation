# IAM Least Privilege Design — KijaniKiosk

**Author:** KijaniKiosk Engineering Team  
**Date:** March 24, 2026

---

## Overview

This document defines an IAM (Identity and Access Management) role and policy for a specific application task, following the **principle of least privilege**: grant only the exact permissions required to perform the task — nothing more.

---

## Application Task: Order Processor Service

### What does it do?

The **Order Processor** is a backend service that handles the lifecycle of a customer order. When a customer places an order, this service:

1. Reads the order message from an **SQS queue** (`kijanikiosk-orders-queue`).
2. Stores the generated PDF order receipt in an **S3 bucket** (`kijanikiosk-order-receipts`).
3. Publishes an order-confirmed event to an **SNS topic** (`kijanikiosk-order-events`) to trigger downstream services (inventory update, email notification).
4. Writes structured application logs to **CloudWatch Logs**.

The service runs as a **containerised ECS task** inside the private subnet. It never needs to access the internet directly, manage IAM users, modify infrastructure, or touch any other S3 bucket or SQS queue.

---

## Why Least Privilege Matters Here

If this service were granted overly broad permissions (e.g., `s3:*` or `AdministratorAccess`), a compromised container could:

- Read or delete **all** S3 buckets, including other customers' data.
- Publish to **any** SNS topic, disrupting other platform workflows.
- Drain messages from **any** SQS queue, breaking other services.
- Modify IAM policies, enabling full privilege escalation.

Least privilege limits the blast radius of a container compromise to only the resources this specific service legitimately needs.

---

## IAM Role

### Role Name: `kijanikiosk-order-processor-role`

```json
{
  "RoleName": "kijanikiosk-order-processor-role",
  "Description": "Grants the Order Processor ECS task minimum permissions to consume the orders queue, store receipts in S3, publish order events to SNS, and write logs to CloudWatch.",
  "AssumeRolePolicyDocument": {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
}
```

**Trust policy note:** Only ECS tasks (`ecs-tasks.amazonaws.com`) can assume this role. No human users, no EC2 instances, no Lambda functions — only this specific service type can obtain the role's credentials.

---

## IAM Policy

### Policy Name: `kijanikiosk-order-processor-policy`

```json
{
  "Version": "2012-10-17",
  "Statement": [

    {
      "Sid": "ConsumeOrderQueue",
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:af-south-1:123456789012:kijanikiosk-orders-queue"
    },

    {
      "Sid": "StoreOrderReceipts",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::kijanikiosk-order-receipts/*"
    },

    {
      "Sid": "PublishOrderEvents",
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:af-south-1:123456789012:kijanikiosk-order-events"
    },

    {
      "Sid": "WriteApplicationLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:af-south-1:123456789012:log-group:/kijanikiosk/order-processor:*"
    }

  ]
}
```

---

## Permission-by-Permission Justification

| Permission | Resource | Why granted | Why NOT broader |
|---|---|---|---|
| `sqs:ReceiveMessage` | Orders queue only | Service polls for new orders to process | No access to any other queues |
| `sqs:DeleteMessage` | Orders queue only | Must acknowledge processed messages to prevent re-delivery | No `sqs:SendMessage` — service only consumes |
| `sqs:GetQueueAttributes` | Orders queue only | Needed for queue depth checks in health monitoring | No `sqs:ListQueues` — no need to enumerate all queues |
| `s3:PutObject` | `kijanikiosk-order-receipts/*` only | Writes generated PDF receipts | No `s3:DeleteObject` — receipts are immutable audit records |
| `s3:GetObject` | `kijanikiosk-order-receipts/*` only | Re-reads a receipt if resend is needed | No access to any other bucket or prefix |
| `sns:Publish` | Order events topic only | Notifies downstream services of confirmed orders | No `sns:Subscribe`, `sns:CreateTopic`, or access to other topics |
| `logs:CreateLogStream` | Order processor log group only | Creates a log stream when the container starts | No access to other log groups |
| `logs:PutLogEvents` | Order processor log group only | Writes structured application logs | No `logs:DeleteLogGroup` or access to other groups |

---

## Permissions Explicitly Withheld

| Permission | Reason withheld |
|---|---|
| `s3:DeleteObject` | Receipts are immutable audit records; the service must never delete them |
| `s3:ListBucket` | Service does not need to enumerate the receipts bucket |
| `iam:*` | The service has no identity management responsibilities |
| `ec2:*` | The service must not manage infrastructure |
| `rds:*` | Database access uses application-level credentials (stored in AWS Secrets Manager), not IAM |
| `sqs:SendMessage` | Service is a queue consumer only, not a producer |
| `sns:Subscribe` | Service publishes events but never manages subscriptions |

---

## Additional Hardening

### Enforce encryption at rest on S3 uploads

Add a condition to the `StoreOrderReceipts` statement to reject any upload that does not use KMS encryption:

```json
"Condition": {
  "StringEquals": {
    "s3:x-amz-server-side-encryption": "aws:kms"
  }
}
```

This means even if the application code forgets to set encryption headers, the policy itself will deny the write — a defence-in-depth measure.

### Scope by ECS cluster (optional future hardening)

```json
"Condition": {
  "ArnLike": {
    "aws:SourceArn": "arn:aws:ecs:af-south-1:123456789012:cluster/kijanikiosk-prod"
  }
}
```

This ensures the role can only be assumed by tasks running in the specific production ECS cluster, preventing the policy from being reused by tasks in other clusters.

---

## Summary

The `kijanikiosk-order-processor-role` applies least privilege by:

1. **Naming every resource explicitly by ARN** — no wildcard resource names.
2. **Listing only the exact actions needed** — no `Action: "*"`.
3. **Restricting trust to ECS tasks only** — no humans or other service types can assume it.
4. **Omitting every permission the service does not need** — even seemingly harmless ones.

The result is that a compromised Order Processor container can only interact with the orders queue, the receipts bucket, and the order events topic — nothing else in the AWS account.
