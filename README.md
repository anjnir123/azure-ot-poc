# Azure IoT/OT-to-Cloud Secure Data Pipeline POC

**Tech Stack:** Azure IoT Hub | Stream Analytics | Key Vault | Terraform | Python  
**Frameworks:** Microsoft Cloud Adoption Framework (CAF) | Well-Architected Framework (WAF)

---
### Description
This project shows a simple and secure way to send data from OT systems (like sensors) to the cloud using Azure.

I simulated a wellhead sensor using Python that sends real-time data (pressure, temperature, flow rate) to Azure IoT Hub. The data is then processed using Stream Analytics to calculate averages and detect high-pressure events.

All infrastructure is created using Terraform, and sensitive data is stored securely in Key Vault (no hardcoded secrets).

### The Architecture Solution
**One-way data flow from OT to IT.** The cloud consumes OT data but never sends commands back to OT equipment. Network segregation is enforced at the firewall/DMZ level.

### What this project does
Sends real-time sensor data to Azure
Processes data using Stream Analytics
Detects anomalies (like high pressure)
Stores processed data in Blob Storage
Keeps secrets secure using Key Vault

### Output
This setup shows how OT systems can safely send data to the cloud without exposing them to security risks.
---

