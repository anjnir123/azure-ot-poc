# Azure IoT/OT-to-Cloud Secure Data Pipeline
## Proof of Concept — Energy Sector IT/OT Integration

**Author:** Anjali Soosai  
**Tech Stack:** Azure IoT Hub | Stream Analytics | Key Vault | Terraform | Python  
**Frameworks:** Microsoft Cloud Adoption Framework (CAF) | Well-Architected Framework (WAF)

---

## What This Project Demonstrates

This project simulates a real-world scenario in the **oil and gas industry**: securely ingesting operational data from wellhead field sensors into Azure for real-time analytics — while maintaining strict **IT/OT network segregation**.

### The Business Problem
Energy companies like Crescent Energy have field assets (wellheads, pipelines, compressor stations) with **Operational Technology (OT) systems** — SCADA servers, PLCs, and sensors — that generate valuable operational data. Getting this data to the cloud for analytics, predictive maintenance, and dashboards creates enormous business value. But connecting OT systems to IT networks introduces serious security risk — a cyberattack on OT equipment can cause physical damage, safety incidents, or environmental violations (see: Colonial Pipeline incident).

### The Architecture Solution
**One-way data flow from OT to IT.** The cloud consumes OT data but never sends commands back to OT equipment. Network segregation is enforced at the firewall/DMZ level.

---

## Architecture

![Architecture Diagram](diagrams/architecture.png)

```
[Wellhead Sensor] --> [SCADA/Historian] --> [Firewall/DMZ] --> [Azure IoT Hub]
                                                  ↑
                                         ONE-WAY ONLY
                                         No return path

[Azure IoT Hub] --> [Stream Analytics] --> [Data Lake Storage]
                                       --> [Alerts Container]
                                   
[Azure Monitor] --> Email alerts when readings exceed thresholds
[Azure Key Vault] --> Stores all secrets (no hardcoded credentials)
[Terraform] --> Provisions ALL infrastructure (IaC)
```

---

## Components

| Component | Azure Service | Purpose |
|-----------|--------------|---------|
| OT Sensor | Python Simulator | Represents wellhead device sending pressure/temp/flow data |
| Secure Ingest | Azure IoT Hub (S1) | Authenticated device-to-cloud message ingestion |
| Real-time Processing | Stream Analytics | SQL-like queries on live sensor data stream |
| Data Lake | Azure Storage Account | Stores processed readings and alerts |
| Secrets Management | Azure Key Vault | Stores connection strings — no hardcoded credentials |
| Observability | Azure Monitor | Alerts when device goes offline or readings are anomalous |
| Infrastructure | Terraform | All resources provisioned as code (CAF principles) |

---

## CAF & WAF Alignment

This architecture follows **Microsoft Cloud Adoption Framework (CAF)** and **Well-Architected Framework (WAF)** principles:

**CAF - Ready Phase (Landing Zone):**
- Resource Group with proper tagging strategy
- Key Vault for centralized secrets management
- Managed Identity authentication (no stored credentials)
- All infrastructure as code (Terraform)

**WAF - Security Pillar:**
- Zero hardcoded credentials — all secrets in Key Vault
- Private storage containers (no public access)
- Managed Identity for service-to-service authentication
- HTTPS/TLS 1.2 minimum on all services

**WAF - Reliability Pillar:**
- Azure Monitor alerts for device connectivity
- Stream Analytics handles late-arriving events (60s grace)
- Dual output streams (normal data + alerts)

**WAF - Cost Optimization Pillar:**
- IoT Hub S1 tier (cheapest that supports routing)
- LRS storage (locally redundant — appropriate for POC)
- Stream Analytics 1 streaming unit (minimum)

**WAF - Operational Excellence Pillar:**
- All infrastructure managed by Terraform
- Output organized by date/time for easy querying
- Comprehensive logging in Python simulator

---

## How to Deploy

### Prerequisites
- Azure free account (portal.azure.com)
- Azure CLI installed and authenticated (`az login`)
- Terraform 1.5+ installed
- Python 3.9+

### Step 1: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 2: Register IoT Device
```bash
# Register device
az iot hub device-identity create \
  --device-id wellhead-TX-001 \
  --hub-name iothub-crescent-ot-poc

# Get device connection string
az iot hub device-identity connection-string show \
  --device-id wellhead-TX-001 \
  --hub-name iothub-crescent-ot-poc \
  --query connectionString -o tsv
```

### Step 3: Update Key Vault Secret
```bash
az keyvault secret set \
  --vault-name kv-crescent-poc-01 \
  --name iothub-device-connection-string \
  --value "HostName=iothub-crescent-ot-poc.azure-devices.net;DeviceId=wellhead-TX-001;SharedAccessKey=YOUR_KEY"
```

### Step 4: Start Stream Analytics Job
```bash
az stream-analytics job start \
  --name sa-crescent-ot-poc \
  --resource-group rg-ot-poc-dev \
  --output-start-mode JobStartTime
```

### Step 5: Run Sensor Simulator
```bash
cd simulator
pip install -r requirements.txt
set KEY_VAULT_URI=https://kv-crescent-poc-01.vault.azure.net/
python sensor_simulator.py
```

---

## What You'll See Running

```
2024-04-18 10:30:00 | INFO | Connected to Azure IoT Hub successfully!
2024-04-18 10:30:00 | INFO | Starting to send sensor data...
2024-04-18 10:30:05 | INFO | Msg #0001 | pressure=2345.67 PSI | temp=187.3°F | flow=1234.5 BPD | status=normal
2024-04-18 10:30:10 | INFO | Msg #0002 | pressure=2412.89 PSI | temp=192.1°F | flow=1189.3 BPD | status=normal
...
2024-04-18 10:31:45 | WARNING | !!! GENERATING HIGH PRESSURE ANOMALY: 2891.23 PSI !!!
2024-04-18 10:31:45 | WARNING | Msg #0020 | ALERT: pressure=2891.23 PSI | temp=188.4°F | flow=1267.8 BPD | status=WARNING
```

After ~2 minutes, check Azure Storage for processed output files.

---

## IT/OT Security Design Decisions

### Why One-Way Data Flow?
OT systems (SCADA, PLCs) often run legacy operating systems that cannot be patched. Allowing any return path from IT/cloud to OT creates a vector for cyberattacks to reach physical equipment. The Colonial Pipeline incident (2021) demonstrated how OT exposure leads to real-world operational impact.

### Why Azure IoT Hub?
IoT Hub is specifically designed as the secure boundary for device-to-cloud communication. It:
- Authenticates every device with unique credentials
- Supports X.509 certificate authentication (enterprise)
- Provides per-device telemetry and monitoring
- Scales to millions of devices

### Why Key Vault for Secrets?
Never hardcode connection strings or credentials in source code. If the code is committed to a public GitHub repo (or even private), credentials are exposed. Key Vault + Managed Identity means:
- Zero credentials in code
- Automatic credential rotation support
- Full audit log of every secret access

---

## Clean Up (After Demo)
```bash
cd terraform
terraform destroy
```
This removes ALL resources, stopping Azure charges.
