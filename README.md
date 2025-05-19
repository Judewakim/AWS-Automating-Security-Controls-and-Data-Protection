# AWS Automating Security Controls and Data Protection

> **Enhancing Application Security Posture with Automated Security Controls and Data Protection**

## 📝 Lab Scenario

You are a **Solutions Architect** at **DataTech Innovations**, a data analytics company. The organization aims to strengthen its security posture and implement **automated security controls** using:

- **Amazon RDS**
- **AWS CloudTrail**
- **Amazon CloudWatch**
- **AWS EC2**
- **Terraform (IaC)**

### 🌟 Project: **DataGuardian**
DataTech Innovations is developing a cutting-edge security analytics tool, that ensures compliance. The task is to develop a solution to monitor and automatically remediate security configurations on unencrypted EC2 EBS volumes and RDS instances by automatically identifying unencrypted instances and volumes, creating encrypted versions, then automatically swapping them after-hours. 

---

## 🎯 Objectives

✔ **Automate Security Controls** – Monitor & remediate security configurations in real-time.<br>
✔ **Ensure Data Protection** – Enforce encryption for RDS and EC2 instances.<br>
✔ **Enable Monitoring & Logging** – Utilize CloudTrail & CloudWatch for security insights. <br>

---

## 📌 Architecture Overview

🔹 **AWS Config** continuously checks RDS & EC2 encryption status.<br>
🔹 **AWS Lambda** triggers remediation when a non-compliant resource is detected.<br>
🔹 **AWS CloudTrail & CloudWatch** track all API calls & provide monitoring dashboards.

---

## ⚡ Prerequisites

Before deploying this solution, ensure you have:

- ✅ An **AWS account** with permissions to manage RDS, EC2, Lambda, Config, CloudTrail, and CloudWatch.
- ✅ **AWS CLI** installed & configured.
- ✅ **Terraform** installed for infrastructure as code deployment.

---

## 🚀 Deployment Instructions

### 1️⃣ **Clone the Repository**
```bash
 git clone https://github.com/Judewakim/AWS-Automating-Security-Controls-and-Data-Protection.git
 cd AWS-Automating-Security-Controls-and-Data-Protection
```

### 2️⃣ **Review and Modify Configuration**
- Open `script.tf` and modify any parameters as needed.

### 3️⃣ **Deploy the Infrastructure**
```bash
terraform init
terraform apply
```
Confirm the deployment when prompted.

### 4️⃣ **Verify Deployment**
- Check **AWS Console** to ensure AWS Config rules, Lambda functions, and IAM roles are created.
- Review **AWS CloudTrail & CloudWatch** logs for activity tracking.

---

## 🗑 Cleanup

To remove all deployed resources, run:
```bash
./deletion.sh
```

Or, use Terraform:
```bash
terraform destroy
```

---

## 📚 References

📌 [Automated Security Response on AWS](https://aws.amazon.com/solutions/implementations/automated-security-response-on-aws/)<br>
📌 [Implementing Security Controls on AWS](https://docs.aws.amazon.com/prescriptive-guidance/latest/aws-security-controls/introduction.html)<br>
📌 [Automate Data Protection](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_protect_data_rest_automate_protection.html)

---

> **Note:** This lab is based on content from *Udemy via Level Up.*

💡 **Happy Securing! 🔒**

