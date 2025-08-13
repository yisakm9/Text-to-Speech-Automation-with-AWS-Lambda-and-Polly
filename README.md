
# Text-to-Speech Automation with AWS Lambda and Polly

This project automates the generation of speech (MP3) from text using **AWS Lambda**, **Amazon Polly**, and **Amazon S3**.
The system supports two workflows:

1. API Gateway Invocation – Clients send text via an API request.
2. S3 Trigger – Upload a '.txt' file to S3, and the Lambda function automatically generates an MP3.



Architecture Diagram

mermaid
flowchart TD
    A[API Client / S3 Upload] -->|1. API POST / S3 Trigger| B[AWS Lambda]
    B -->|Text-to-Speech| C[Amazon Polly]
    C -->|MP3 File| D[S3 Output Bucket (AUDIO_BUCKET)]
    A2[S3 Text Input Bucket] -->|Trigger| B




# How It Works

# 1. Lambda Function (`lambda_function.py`)

API Gateway Invocation:

  * Accepts a POST request containing `{"text": "Hello world"}`.
  * Converts the text to speech using **Amazon Polly**.
  * Stores the resulting `.mp3` file in the target `AUDIO_BUCKET`.

  S3 Trigger:

  * Triggered when a `.txt` file is uploaded to an input S3 bucket.
  * Downloads the text file, converts it to speech, and uploads the `.mp3` back to the `AUDIO_BUCKET`.

Shared Functionality:**

  * Uses `boto3` to interact with S3 and Polly.
  * Outputs the audio file URL in the response.

# Key Environment Variable:

* `AUDIO_BUCKET`: Name of the S3 bucket where MP3 files will be stored.



# 2. Terraform (`main.tf`)

The Terraform configuration:

* Creates:

  * AWS Lambda function
  * S3 buckets (input and output)
  * API Gateway for triggering Lambda
  * Required IAM roles and permissions
* Configures:

  * Lambda event notifications for S3
  * API Gateway integration with Lambda



# Deployment Steps

1. Provision Infrastructure:

   bash
   terraform init
   terraform apply
   

2. Deploy Lambda Code:

   * Zip the `lambda_function.py`.
   * Upload through Terraform or AWS Console.

3. Test:

   API: Send a POST request:

     bash
     curl -X POST https://<api_gateway_url>/text-to-speech \
          -H "Content-Type: application/json" \
          -d '{"text":"Hello World"}'
     
   S3: Upload `example.txt` to the input S3 bucket.

4. Check Output:
   Generated `.mp3` files will appear in the `AUDIO_BUCKET`.



# Use Cases

* Podcast automation
* Audiobooks from uploaded text
* Accessibility (screen readers)
* Voice-enabled notifications



# Architecture Highlights

Serverless – No servers to manage.
Scalable – Automatically scales with AWS Lambda.
Multi-input support – Works with API and S3 triggers.
Cost-efficient – Pay only for what you use.


