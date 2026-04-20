# ⚡ ANJALI'S COMPLETE PROJECT GUIDE
## Do This + Talk About It Confidently
### Azure IoT/OT-to-Cloud Pipeline — Every Command, Every Word

---

# ═══════════════════════════════════════════
# PART A: BUILD THE PROJECT (Step by Step)
# ═══════════════════════════════════════════

## BEFORE YOU START — Install These (One Time Only)

### 1. Install Azure CLI
- Go to: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
- Windows: Download the MSI installer and run it
- After install, open a new terminal/command prompt and type: az --version
- You should see version info printed

### 2. Install Terraform
- Go to: https://developer.hashicorp.com/terraform/install
- Windows: Download the zip, extract terraform.exe, put it in C:\Windows\System32\
- Verify: terraform --version

### 3. Install Python 3.9+
- Go to: https://www.python.org/downloads/
- Download and install (check "Add to PATH" during install)
- Verify: python --version

### 4. Install VS Code
- Go to: https://code.visualstudio.com/
- Download and install
- Install extensions: "HashiCorp Terraform" and "Python"

---

## STEP 1: Log In to Azure (2 minutes)

Open your terminal (Command Prompt or PowerShell on Windows) and run:

```
az login
```

A browser window opens. Log in with your Azure account.
When done, your terminal shows your subscription info.

Then run this to see your subscription ID (you'll need it):
```
az account show
```

---

## STEP 2: Create Your Project Folder (3 minutes)

Copy the files from this package into this folder structure:

```
ot-poc-project/
  terraform/
    providers.tf       ← COPY from this package
    variables.tf       ← COPY from this package
    main.tf            ← COPY from this package
    outputs.tf         ← COPY from this package
  simulator/
    sensor_simulator.py  ← COPY from this package
    requirements.txt     ← COPY from this package
  diagrams/
    architecture.drawio  ← COPY from this package
  README.md              ← COPY from this package
```

Create it like this in terminal:
```
mkdir ot-poc-project
mkdir ot-poc-project\terraform
mkdir ot-poc-project\simulator
mkdir ot-poc-project\diagrams
```

---

## STEP 3: IMPORTANT — Update the Storage Account Name

Open terraform/variables.tf
Find this line:
```
default = "sacrescentot2024"
```

Storage account names must be GLOBALLY UNIQUE across all of Azure.
Change "sacrescentot2024" to something like "sacrescentot" + your initials + random 4 numbers.
Example: "sacrescentotans9821"

Same for Key Vault name — change "kv-crescent-poc-01" to something like "kv-crescent-ans01"

---

## STEP 4: Deploy Infrastructure with Terraform (15 minutes)

Open terminal, navigate to your terraform folder:
```
cd ot-poc-project\terraform
```

Initialize Terraform (downloads the Azure provider plugin):
```
terraform init
```
You should see: "Terraform has been successfully initialized!"

Preview what Terraform will create (READ THIS, don't skip it):
```
terraform plan
```
You'll see a list of ~10 resources it will create.
Green + signs mean it will CREATE these resources.

Deploy everything to Azure:
```
terraform apply
```
When it asks "Do you want to perform these actions?" — type: yes

Wait 5-10 minutes. When done you'll see:
"Apply complete! Resources: X added"

And it prints your outputs including the IoT Hub name and Key Vault URI.
SAVE THESE VALUES — you'll need them.

---

## STEP 5: Register Your IoT Device (5 minutes)

The IoT Hub is deployed but it doesn't have any devices yet.
Register a device called "wellhead-TX-001":

First, install the IoT Hub extension:
```
az extension add --name azure-iot
```

Register the device:
```
az iot hub device-identity create --device-id wellhead-TX-001 --hub-name iothub-crescent-ot-poc
```

Get the device connection string (COPY THE OUTPUT — you need this next):
```
az iot hub device-identity connection-string show --device-id wellhead-TX-001 --hub-name iothub-crescent-ot-poc --query connectionString -o tsv
```

It will output something like:
HostName=iothub-crescent-ot-poc.azure-devices.net;DeviceId=wellhead-TX-001;SharedAccessKey=abc123...

COPY THAT ENTIRE STRING.

---

## STEP 6: Store the Connection String in Key Vault (2 minutes)

Replace YOUR_VAULT_NAME and YOUR_CONNECTION_STRING below:

```
az keyvault secret set --vault-name kv-crescent-ans01 --name iothub-device-connection-string --value "PASTE_YOUR_CONNECTION_STRING_HERE"
```

This is why we use Key Vault — the Python script will read this from here at runtime.
Never hardcode it in the Python file.

---

## STEP 7: Start the Stream Analytics Job (2 minutes)

```
az stream-analytics job start --name sa-crescent-ot-poc --resource-group rg-ot-poc-dev --output-start-mode JobStartTime
```

Starting takes 1-2 minutes. You can also start it in the Azure portal:
Portal → Stream Analytics Jobs → sa-crescent-ot-poc → Start

---

## STEP 8: Set Up Monitoring Alerts (5 minutes in Portal)

Go to portal.azure.com

First, create an Action Group (who gets notified):
1. Search "Monitor" in the top search bar → Click Azure Monitor
2. Click "Alerts" in the left menu
3. Click "Action groups" → "Create"
4. Resource group: rg-ot-poc-dev
5. Action group name: ag-ot-poc-ops
6. Click "Notifications" tab → Add email → enter YOUR email
7. Click "Review + create" → "Create"

Create an Alert for Device Offline:
1. Back in Monitor → Alerts → "Create alert rule"
2. Click "Select resource" → find your IoT Hub (iothub-crescent-ot-poc)
3. Click "Add condition" → search "d2c" → select "d2c.telemetry.ingress.allProtocol"
4. Operator: Less than | Threshold: 1 | Period: 5 minutes
5. Click "Select action group" → pick ag-ot-poc-ops
6. Alert rule name: "alert-device-offline"
7. Create the alert

---

## STEP 9: Run the Python Simulator (2 minutes setup)

Open a NEW terminal window. Navigate to the simulator folder:
```
cd ot-poc-project\simulator
```

Install the required Python libraries:
```
pip install -r requirements.txt
```

Set the Key Vault URI environment variable (replace with YOUR vault name):
```
set KEY_VAULT_URI=https://kv-crescent-ans01.vault.azure.net/
```

Run the simulator:
```
python sensor_simulator.py
```

You should see output like:
```
2024-04-18 10:30:00 | INFO | OT SENSOR SIMULATOR STARTING
2024-04-18 10:30:00 | INFO | Connected to Azure IoT Hub successfully!
2024-04-18 10:30:05 | INFO | Msg #0001 | pressure=2345.67 PSI | temp=187.3°F | flow=1234.5 BPD
2024-04-18 10:30:10 | INFO | Msg #0002 | pressure=2412.89 PSI | temp=192.1°F | flow=1189.3 BPD
```

Every 20th message shows:
```
WARNING | !!! GENERATING HIGH PRESSURE ANOMALY: 2891.23 PSI !!!
```

Leave it running for 2-3 minutes.

---

## STEP 10: Verify It's Working in the Azure Portal

1. Go to portal.azure.com → Search "IoT Hub" → iothub-crescent-ot-poc
   - Click "Overview" → You'll see "Messages received" count going up ✅

2. Go to your Storage Account → sacrescentot[yourname]
   - Click "Containers" → sensor-data
   - Wait 2 minutes after simulator starts
   - You'll see folders: processed/2024-04-18/10/ with JSON files inside ✅

3. Click a JSON file → Download → Open in VS Code
   - You'll see processed readings with averages ✅

4. In your alerts container "pressure-alerts" — check after a WARNING message
   - You'll see the high-pressure events captured separately ✅

---

## STEP 11: Import Architecture Diagram to draw.io

1. Go to app.diagrams.net in browser (free, no install)
2. Click "Open Existing Diagram"
3. Open the file: ot-poc-project/diagrams/architecture.drawio
4. The complete color-coded diagram opens
5. Export as PNG: File → Export As → PNG → Save as architecture.png
6. Copy the PNG to your ot-poc-project folder

---

## STEP 12: Push to GitHub (5 minutes)

Create a GitHub account at github.com if you don't have one.

Install Git: https://git-scm.com/downloads

In your project folder:
```
cd ot-poc-project
git init
git add .
git commit -m "Initial commit: Azure IoT/OT POC for Crescent Energy"
```

On GitHub: Create new repository called "azure-iot-ot-poc" (public)
Follow the instructions GitHub shows to push your code.

---

## STEP 13: Cleanup (After Demo — Stops Azure Charges)

```
cd terraform
terraform destroy
```
Type: yes

This removes ALL resources and stops any charges.

---

# ═══════════════════════════════════════════
# PART B: HOW TO TALK ABOUT IT CONFIDENTLY
# Complete Casual Talking Script
# Read This Out Loud Until It Feels Natural
# ═══════════════════════════════════════════

---

## 🎤 INTRO — When They Ask "Tell Me About Your OT Project"

> "So after my conversation with Azkar, I built a proof-of-concept project that directly addresses something Crescent cares about — getting operational data from field equipment into Azure securely, while keeping the IT and OT networks properly segregated.

> Let me show you the architecture diagram first, and then I'll walk you through what each piece does and why I made the decisions I made."

[Open GitHub repo or draw.io diagram on screen]

> "So the architecture has three zones. On the far left is the OT network — that's the isolated, air-gapped environment where the actual field equipment lives. In the middle is the firewall and DMZ. And on the right is Azure — the IT side. The fundamental security principle of the whole thing is: data flows one way, from OT to IT, and there is no return path. The cloud can receive data from the field, but it cannot send commands back to field equipment. That segregation is what keeps a cyberattack on cloud systems from becoming a physical safety incident."

---

## 🔧 HOW TO TALK ABOUT EACH COMPONENT

### The Python Sensor Simulator

> "So in a real Crescent Energy environment, this would be a physical wellhead sensor — measuring pressure, temperature, and flow rate — connected to a SCADA server on the OT network. I don't have actual wellhead equipment in my apartment, obviously — so I built a Python simulator that generates realistic sensor data.

> The simulator sends a JSON message every 5 seconds with device ID, timestamp, pressure in PSI, temperature in Fahrenheit, and barrels per day flow rate. Every 20th message I deliberately trigger a high-pressure anomaly — pressure above 2700 PSI — to test that my alerting pipeline actually works.

> Here's what makes it secure: the simulator doesn't have the IoT Hub connection string hardcoded anywhere in the code. If this code went to a public GitHub repo, there's nothing sensitive exposed. Instead, the script authenticates to Azure Key Vault at startup using the Azure DefaultAzureCredential — which in my local setup picks up my az login session, and in production on AKS would use a pod Managed Identity — and fetches the connection string from Key Vault at runtime. That's the security pattern I'd apply in any real project."

### Azure IoT Hub

> "IoT Hub is the heart of the architecture — it's the secure crossing point between the OT and IT networks. Every device that wants to send data to Azure has to be registered in IoT Hub's device registry and authenticated. The simulator uses a device-specific connection string with a shared access key. In a production implementation you'd use X.509 certificates for stronger authentication.

> The key thing about IoT Hub is that it's designed for this exact use case — device to cloud messaging. The data flows from the device TO the hub. The hub doesn't push commands back to devices in this architecture. That device-to-cloud only pattern is the software-level enforcement of the one-way data flow principle. The firewall handles it at the network level, and IoT Hub enforces it at the application level."

### Azure Stream Analytics

> "Stream Analytics is a real-time event processing engine. Think of it as SQL running on a live data stream instead of a static database table. It reads from IoT Hub continuously and I wrote two queries.

> The first query uses a tumbling window — which means it groups the data into 1-minute non-overlapping buckets — and calculates averages: average pressure per device per minute, max temperature, average flow rate, and reading count. That output goes to my 'sensor-data' container in the storage account.

> The second query has no windowing — it immediately captures any reading where pressure exceeds 2700 PSI and routes it to a separate 'pressure-alerts' container. So high-pressure events are captured instantly without waiting for the 1-minute window. That's the real-time anomaly detection layer.

> The Stream Analytics SQL looks like this: SELECT device_id, AVG(pressure_psi), MAX(temperature_f) INTO bloboutput FROM iothubinput GROUP BY device_id, TumblingWindow(minute, 1). Very readable — it's almost exactly like regular SQL but running on live data."

### Azure Storage Account

> "I'm using a standard Azure Storage Account as a simplified data lake. It has two containers: sensor-data for the processed average readings, and pressure-alerts for the anomaly events. The output is organized in folders by date and time — so it looks like processed/2024-04-18/10/ — which makes it easy to query a specific time range. In a production environment this would be Azure Data Lake Storage Gen2 with proper hierarchical namespace, and you'd have Databricks or Synapse Analytics reading from it for deeper analysis and ML model training. But for the POC, the storage account demonstrates the concept."

### Azure Key Vault

> "Key Vault is where I store the IoT Hub device connection string. The Python simulator connects to Key Vault first, retrieves the secret, and then uses it to connect to IoT Hub. Nothing sensitive exists in the code. If I need to rotate the connection string — which you'd do periodically in production — I update the Key Vault secret and the next time the simulator starts it automatically picks up the new value. No code changes, no redeployment.

> This is the WAF Security pillar in practice. Zero hardcoded credentials, managed identity for access, and a full audit log of every access to that secret sitting in Key Vault's activity log."

### Azure Monitor Alerts

> "I set up two types of alerts. First, a device offline alert — if the IoT Hub stops receiving messages from wellhead-TX-001 for 5 minutes, an alert fires to the operations team email. In a real wellhead scenario that could mean the sensor failed, the network went down, or the OT server crashed. Second, the high-pressure events captured in the alerts container can feed into more sophisticated alerting through Logic Apps or Azure Functions.

> This is the self-healing system concept Azkar talked about. The first layer is detection — I know something is wrong. The next layer would be automated response — trigger a workflow, notify field operations, or in a more advanced implementation, adjust safe operating parameters."

### Terraform (IaC)

> "Everything in this project — the IoT Hub, the Storage Account, the Key Vault, the Stream Analytics job, all the access policies and security settings — was provisioned with Terraform. I wrote four files: providers.tf which configures the Azure provider, variables.tf which defines all the configurable inputs, main.tf which defines all the resources, and outputs.tf which prints the important values after deployment.

> The reason this matters for Crescent: if I need to spin up this same architecture for a second environment, or for a newly acquired company's assets, I run terraform apply with different variable values. The architecture is repeatable and consistent. That's the CAF principle — infrastructure as code so your environment is never a mystery. And if something breaks, you can terraform destroy and terraform apply to rebuild the entire thing from scratch in 10 minutes. That's your disaster recovery built into your IaC."

---

## 💬 HOW TO ANSWER FOLLOW-UP QUESTIONS

### "Why did you choose IoT Hub instead of just sending directly to Event Hubs?"

> "IoT Hub is specifically designed for the device-to-cloud pattern in OT environments. Event Hubs is a great streaming service but it doesn't have the device management and authentication layer that IoT Hub has. With IoT Hub I get a device registry — I know exactly which devices are registered, I can revoke individual device access without affecting others, I get per-device monitoring and diagnostics, and I get the device-to-cloud message routing built in. For a wellhead sensor scenario, that device identity and authentication layer is important. You need to know that the message you're receiving actually came from wellhead-TX-001 and not from a spoofed device."

### "How would this scale to hundreds of wellheads?"

> "IoT Hub S1 tier supports 400,000 messages per day per unit. If I add more units, it scales proportionally. For hundreds of wellheads sending data every 5 seconds, I'd calculate the daily message volume — 100 devices × 17,280 messages per day (one every 5 seconds) = 1.7 million messages per day, so I'd need about 5 IoT Hub units. The Stream Analytics job scales independently — I'd increase streaming units based on the data throughput. The Storage Account is essentially unlimited. So the architecture scales horizontally without redesign, just by increasing the units on the managed services."

### "What would you add to make this production-ready?"

> "Several things. First, X.509 certificate-based device authentication instead of shared access keys — much stronger security for field devices. Second, Azure Data Lake Storage Gen2 instead of the basic storage account, with a proper data schema and Databricks for advanced analytics. Third, Azure Digital Twins to model the physical asset hierarchy — which wellhead is in which field, which field is in which basin. Fourth, a proper CI/CD pipeline in GitHub Actions to deploy infrastructure changes through code review. Fifth, disaster recovery — geo-replication on the storage and an IoT Hub in a secondary region with DNS failover. Sixth, network integration — if Crescent has an ExpressRoute or VPN from the on-premises OT network, the IoT Hub traffic would traverse that private connection rather than the public internet. Those are the gaps between a POC and production."

### "How does this align with CAF and WAF?"

> "I designed this with both frameworks in mind. From a CAF perspective, this is the Ready phase foundation — Key Vault for secrets, tagged resources, Terraform IaC, proper resource group structure. In a full CAF landing zone, this resource group would be a spoke in a hub-spoke architecture, with the hub providing the centralized networking and firewall that enforces the IT/OT segregation at the network layer.

> From a WAF perspective: Security pillar — zero hardcoded credentials, Key Vault, managed identity, private storage. Reliability pillar — Stream Analytics handles late-arriving events up to 60 seconds, dual output streams so an issue with the alerts container doesn't affect the main data pipeline. Cost Optimization pillar — S1 IoT Hub tier, LRS storage, minimum streaming units. Operational Excellence pillar — full Terraform IaC, organized output paths with date partitioning, comprehensive simulator logging. Every architecture decision maps to a specific pillar."

---

## 🎯 THE CLOSING LINE — After Walking Through the Demo

> "So that's the project. What I'm most proud of is not the specific Azure services — it's the architecture principle it demonstrates. Data flows one way from OT to IT. The cloud consumes operational intelligence but never controls physical equipment. Every credential is managed through Key Vault. Every piece of infrastructure is defined as code. Those are the design principles I'd apply at Crescent — not just for this OT integration scenario, but for any cloud architecture work. The specific services might change based on your existing environment and requirements, but those principles are the foundation."

---

## 🔑 QUICK DEFINITIONS — Say These Without Hesitating

**SCADA:** Supervisory Control and Data Acquisition. The OT system that monitors and controls field equipment — pumps, valves, wellheads. Runs on the isolated OT network.

**Historian:** A database (like OSIsoft PI) that stores time-series data from SCADA systems. It's the source of operational data that feeds into the cloud pipeline.

**PLC:** Programmable Logic Controller. A physical hardware device that controls a specific piece of field equipment based on instructions from SCADA.

**Data Diode:** A hardware device that physically only allows data to flow one direction. Even a cyberattack cannot send data back through it. The gold standard for OT/IT segregation.

**DMZ:** Demilitarized Zone. A network segment between OT and IT with strict firewall rules on both sides. The historian server often sits here.

**Tumbling Window:** In Stream Analytics, a time window that groups data into fixed, non-overlapping buckets. "TumblingWindow(minute, 1)" means every 1-minute period is a separate group.

**Managed Identity:** An Azure feature that gives an Azure resource (like a VM or AKS pod) an automatically managed identity in Azure AD. No password to manage or rotate.

**DefaultAzureCredential:** An Azure SDK class that automatically tries multiple authentication methods in order — environment variables, managed identity, then az login credentials. Works locally with az login, works in production with managed identity. Same code, no changes.

**IoT Hub S1 Tier:** The Standard 1 tier of IoT Hub. Cheapest tier that supports message routing and cloud-to-device messaging. 400K messages per day per unit.

**Streaming Units:** The compute capacity for a Stream Analytics job. 1 unit is the minimum and handles light workloads like this POC. More units = more data throughput.

---

> "I built this project specifically for this role, after my conversation with Azkar. It's a proof of concept, not production — but every architectural decision in it reflects how I'd approach the real thing at Crescent."
