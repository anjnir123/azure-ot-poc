"""
=============================================================
OT SENSOR SIMULATOR - Wellhead Device Simulator
=============================================================
PROJECT: Azure IoT/OT-to-Cloud Secure Data Pipeline POC
AUTHOR:  Anjali Soosai

WHAT THIS SCRIPT DOES:
- Simulates a real wellhead OT sensor sending data to Azure IoT Hub
- In a real energy company, this would be running on a small 
  on-premises server in the OT network DMZ (not in the cloud)
- The script reads the IoT Hub connection string from Azure Key Vault
  (never hardcoded - that's the security best practice)
- Every 5 seconds it sends pressure, temperature, and flow rate data
- Every 20th message it triggers a HIGH PRESSURE anomaly to test alerting

HOW TO RUN:
1. pip install -r requirements.txt
2. az login  (authenticate with Azure CLI)
3. Set environment variable: set KEY_VAULT_URI=https://kv-crescent-poc-01.vault.azure.net/
4. python sensor_simulator.py

WHAT YOU SHOULD SEE:
- Messages being sent every 5 seconds
- Occasional HIGH PRESSURE alerts
- Data appearing in Azure Storage after ~2 minutes (Stream Analytics processes it)
=============================================================
"""

import json
import time
import random
import os
import logging
from datetime import datetime, timezone
from azure.iot.device import IoTHubDeviceClient, Message
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

# Set up logging so we can see what's happening
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# ============================================================
# CONFIGURATION
# ============================================================
DEVICE_ID = "wellhead-TX-001"          # Our simulated wellhead device
KEY_VAULT_URI = os.environ.get(        # Read from environment variable
    "KEY_VAULT_URI",
    "https://kv-crescent-poc-01.vault.azure.net/"  # Default - update with your vault name
)
SECRET_NAME = "iothub-device-connection-string"
SEND_INTERVAL_SECONDS = 5              # Send a message every 5 seconds
ANOMALY_EVERY_N_MESSAGES = 20          # Trigger a high-pressure event every 20 messages

# Normal operating ranges for a wellhead
NORMAL_PRESSURE_MIN = 2200.0           # PSI
NORMAL_PRESSURE_MAX = 2600.0           # PSI
NORMAL_TEMP_MIN     = 175.0            # Fahrenheit
NORMAL_TEMP_MAX     = 200.0            # Fahrenheit
NORMAL_FLOW_MIN     = 1000.0           # Barrels per day
NORMAL_FLOW_MAX     = 1500.0           # Barrels per day

# Alert threshold - anything above this triggers an alert
PRESSURE_ALERT_THRESHOLD = 2700.0     # PSI


def get_connection_string_from_keyvault():
    """
    Retrieve the IoT Hub device connection string from Azure Key Vault.
    WHY KEY VAULT? 
    - Never hardcode connection strings in code
    - If your code goes to GitHub, secrets stay safe
    - In production, AKS pods use Managed Identity to access Key Vault
    - In this POC, we use DefaultAzureCredential which picks up your az login session
    """
    logger.info(f"Connecting to Key Vault: {KEY_VAULT_URI}")
    
    # DefaultAzureCredential automatically uses your 'az login' credentials
    # In production on AKS this would use the pod's Managed Identity
    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=KEY_VAULT_URI, credential=credential)
    
    secret = client.get_secret(SECRET_NAME)
    logger.info(f"Successfully retrieved connection string from Key Vault")
    return secret.value


def generate_sensor_reading(message_number):
    """
    Generate a realistic sensor reading from a wellhead device.
    
    Every ANOMALY_EVERY_N_MESSAGES messages, we generate a high-pressure
    reading to simulate an anomaly and test our alerting pipeline.
    """
    # Check if this message should be an anomaly
    is_anomaly = (message_number % ANOMALY_EVERY_N_MESSAGES == 0) and (message_number > 0)
    
    if is_anomaly:
        # HIGH PRESSURE EVENT - simulates a pressure spike in the wellbore
        pressure = round(random.uniform(2800.0, 3000.0), 2)
        status = "WARNING"
        logger.warning(f"!!! GENERATING HIGH PRESSURE ANOMALY: {pressure} PSI !!!")
    else:
        # Normal operating reading
        pressure = round(random.uniform(NORMAL_PRESSURE_MIN, NORMAL_PRESSURE_MAX), 2)
        status = "normal"
    
    temperature = round(random.uniform(NORMAL_TEMP_MIN, NORMAL_TEMP_MAX), 2)
    flow_rate   = round(random.uniform(NORMAL_FLOW_MIN, NORMAL_FLOW_MAX), 2)
    
    reading = {
        "device_id":       DEVICE_ID,
        "timestamp":       datetime.now(timezone.utc).isoformat(),
        "pressure_psi":    pressure,
        "temperature_f":   temperature,
        "flow_rate_bpd":   flow_rate,
        "status":          status,
        "message_number":  message_number,
        "is_anomaly":      is_anomaly
    }
    
    return reading


def run_simulator():
    """
    Main simulator loop.
    
    Architecture flow:
    [This Script] --> [Azure IoT Hub] --> [Stream Analytics] --> [Storage Account]
         ^                  ^                     ^                      ^
    Simulates OT      Secure ingest         Processes stream        Data Lake
    field sensor      boundary (IT/OT       in real-time            stores results
                      crossing point)
    """
    logger.info("=" * 60)
    logger.info("OT SENSOR SIMULATOR STARTING")
    logger.info("=" * 60)
    logger.info(f"Device ID:     {DEVICE_ID}")
    logger.info(f"Key Vault:     {KEY_VAULT_URI}")
    logger.info(f"Send interval: {SEND_INTERVAL_SECONDS} seconds")
    logger.info(f"Anomaly every: {ANOMALY_EVERY_N_MESSAGES} messages")
    logger.info("=" * 60)
    
    # Step 1: Get connection string from Key Vault
    try:
        connection_string = get_connection_string_from_keyvault()
    except Exception as e:
        logger.error(f"Failed to get connection string from Key Vault: {e}")
        logger.error("Make sure you have run 'az login' and updated the Key Vault secret.")
        logger.error("See Step 8 in the guide for instructions.")
        return
    
    # Step 2: Create IoT Hub client
    logger.info("Connecting to Azure IoT Hub...")
    try:
        client = IoTHubDeviceClient.create_from_connection_string(connection_string)
        client.connect()
        logger.info("Connected to IoT Hub successfully!")
    except Exception as e:
        logger.error(f"Failed to connect to IoT Hub: {e}")
        logger.error("Make sure you have updated the Key Vault secret with the real device connection string.")
        return
    
    # Step 3: Send sensor data in a loop
    message_count = 0
    logger.info("\nStarting to send sensor data...")
    logger.info("(Press Ctrl+C to stop)\n")
    
    try:
        while True:
            message_count += 1
            
            # Generate a realistic sensor reading
            reading = generate_sensor_reading(message_count)
            
            # Convert to JSON string
            message_json = json.dumps(reading)
            
            # Create IoT Hub Message object
            message = Message(message_json)
            message.content_type      = "application/json"
            message.content_encoding  = "utf-8"
            
            # Add custom properties (used for routing and filtering)
            message.custom_properties["device_id"] = DEVICE_ID
            message.custom_properties["status"]    = reading["status"]
            
            # SEND TO IOT HUB (Device --> Cloud direction only)
            client.send_message(message)
            
            # Log what we sent
            if reading["is_anomaly"]:
                logger.warning(
                    f"Msg #{message_count:04d} | "
                    f"ALERT: pressure={reading['pressure_psi']} PSI | "
                    f"temp={reading['temperature_f']}°F | "
                    f"flow={reading['flow_rate_bpd']} BPD | "
                    f"status={reading['status']}"
                )
            else:
                logger.info(
                    f"Msg #{message_count:04d} | "
                    f"pressure={reading['pressure_psi']} PSI | "
                    f"temp={reading['temperature_f']}°F | "
                    f"flow={reading['flow_rate_bpd']} BPD | "
                    f"status={reading['status']}"
                )
            
            # Wait before next reading
            time.sleep(SEND_INTERVAL_SECONDS)
    
    except KeyboardInterrupt:
        logger.info("\nSimulator stopped by user (Ctrl+C)")
    except Exception as e:
        logger.error(f"Error sending message: {e}")
    finally:
        logger.info("Disconnecting from IoT Hub...")
        client.disconnect()
        logger.info(f"Done. Sent {message_count} messages total.")


if __name__ == "__main__":
    run_simulator()
