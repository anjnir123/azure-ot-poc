# ============================================================
# DATA SOURCES
# ============================================================

# Get your current Azure account details (needed for Key Vault access policy)
data "azurerm_client_config" "current" {}

# ============================================================
# RESOURCE GROUP
# Think of this as a folder that holds all your Azure resources
# ============================================================
resource "azurerm_resource_group" "ot_poc" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ============================================================
# IOT HUB
# This is the SECURE CROSSING POINT between OT and IT.
# Field sensors (simulated by our Python script) send data HERE.
# IoT Hub authenticates every device before accepting its messages.
# ============================================================
resource "azurerm_iothub" "ot_hub" {
  name                = var.iot_hub_name
  resource_group_name = azurerm_resource_group.ot_poc.name
  location            = azurerm_resource_group.ot_poc.location
  tags                = var.tags

  sku {
    name     = "S1"   # Standard tier - cheapest that supports message routing
    capacity = 1      # 1 unit = 400,000 messages per day (way more than we need)
  }

  # This route sends ALL messages to the built-in endpoint
  # Stream Analytics will read from this endpoint
  fallback_route {
    source         = "DeviceMessages"
    endpoint_names = ["events"]
    enabled        = true
  }
}

# Shared Access Policy - this gives our simulator permission to SEND messages to IoT Hub
# Think of it as a key that the device uses to authenticate
resource "azurerm_iothub_shared_access_policy" "device_send" {
  name                = "device-send-policy"
  resource_group_name = azurerm_resource_group.ot_poc.name
  iothub_name         = azurerm_iothub.ot_hub.name

  device_connect = true  # Allow sending messages (device -> cloud direction only)
}

# ============================================================
# STORAGE ACCOUNT (Simple Data Lake)
# This is where Stream Analytics writes the PROCESSED sensor data.
# In production this would be Azure Data Lake Storage Gen2.
# ============================================================
resource "azurerm_storage_account" "data_lake" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.ot_poc.name
  location                 = azurerm_resource_group.ot_poc.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Locally Redundant Storage - cheapest option
  tags                     = var.tags

  # Security settings
  min_tls_version          = "TLS1_2"
  https_traffic_only_enabled = true
}

# Container inside the storage account where processed data lands
resource "azurerm_storage_container" "sensor_data" {
  name                  = "sensor-data"
  storage_account_name  = azurerm_storage_account.data_lake.name
  container_access_type = "private"  # No public access - secure
}

# Separate container for HIGH PRESSURE ALERTS
resource "azurerm_storage_container" "alerts" {
  name                  = "pressure-alerts"
  storage_account_name  = azurerm_storage_account.data_lake.name
  container_access_type = "private"
}

# ============================================================
# KEY VAULT
# This stores the IoT Hub connection string securely.
# Our Python simulator retrieves it from here at runtime.
# NO secrets are hardcoded anywhere - this is the security best practice.
# ============================================================
resource "azurerm_key_vault" "secrets" {
  name                        = var.key_vault_name
  resource_group_name         = azurerm_resource_group.ot_poc.name
  location                    = azurerm_resource_group.ot_poc.location
  enabled_for_disk_encryption = false
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7   # Minimum - saves cost on free tier
  purge_protection_enabled    = false  # Allow force-delete for POC
  sku_name                    = "standard"
  tags                        = var.tags

  # Access policy: gives YOUR account full access to manage secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
}

# Store the IoT Hub connection string as a secret in Key Vault
# The Python simulator reads this instead of having it hardcoded
resource "azurerm_key_vault_secret" "iothub_connection_string" {
  name         = "iothub-device-connection-string"
  # This is a PLACEHOLDER - you will update this after creating the IoT device
  # See Step 8 in the guide for how to update this value
  value        = "PLACEHOLDER-UPDATE-AFTER-DEVICE-REGISTRATION"
  key_vault_id = azurerm_key_vault.secrets.id

  depends_on = [azurerm_key_vault.secrets]
}

# ============================================================
# STREAM ANALYTICS JOB
# This reads the real-time sensor data stream from IoT Hub,
# processes it (averages, anomaly detection), and writes to Storage.
# Think of it as a real-time SQL engine for streaming data.
# ============================================================
resource "azurerm_stream_analytics_job" "ot_processor" {
  name                                     = var.stream_analytics_job_name
  resource_group_name                      = azurerm_resource_group.ot_poc.name
  location                                 = azurerm_resource_group.ot_poc.location
  compatibility_level                      = "1.2"
  data_locale                              = "en-US"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  streaming_units                          = 1  # Minimum - cheapest option
  tags                                     = var.tags

  # The SQL-like query that processes sensor data
  # This calculates averages per device per minute
  # and separately captures any HIGH PRESSURE events
  transformation_query = <<QUERY
-- Main output: Average readings per device per minute
SELECT
    device_id,
    AVG(pressure_psi)   AS avg_pressure_psi,
    MAX(pressure_psi)   AS max_pressure_psi,
    AVG(temperature_f)  AS avg_temperature_f,
    AVG(flow_rate_bpd)  AS avg_flow_rate_bpd,
    COUNT(*)            AS reading_count,
    System.Timestamp()  AS window_end_utc
INTO
    bloboutput
FROM
    iothubinput TIMESTAMP BY EventEnqueuedUtcTime
GROUP BY
    device_id,
    TumblingWindow(minute, 1)

-- Alert output: Capture high-pressure events immediately (no windowing)
SELECT
    device_id,
    pressure_psi,
    temperature_f,
    EventEnqueuedUtcTime AS alert_time,
    'HIGH_PRESSURE_ALERT' AS alert_type
INTO
    alertoutput
FROM
    iothubinput TIMESTAMP BY EventEnqueuedUtcTime
WHERE
    pressure_psi > 2700
QUERY
}

# INPUT: IoT Hub feeds data into Stream Analytics
resource "azurerm_stream_analytics_stream_input_iothub" "sensor_input" {
  name                         = "iothubinput"
  stream_analytics_job_name    = azurerm_stream_analytics_job.ot_processor.name
  resource_group_name          = azurerm_resource_group.ot_poc.name
  endpoint                     = "messages/events"
  eventhub_consumer_group_name = "$Default"
  iothub_namespace             = azurerm_iothub.ot_hub.name
  shared_access_policy_key     = azurerm_iothub.ot_hub.shared_access_policy[0].primary_key
  shared_access_policy_name    = "iothubowner"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

# OUTPUT 1: Processed averages go to sensor-data container
resource "azurerm_stream_analytics_output_blob" "processed_output" {
  name                      = "bloboutput"
  stream_analytics_job_name = azurerm_stream_analytics_job.ot_processor.name
  resource_group_name       = azurerm_resource_group.ot_poc.name
  storage_account_name      = azurerm_storage_account.data_lake.name
  storage_account_key       = azurerm_storage_account.data_lake.primary_access_key
  storage_container_name    = azurerm_storage_container.sensor_data.name
  path_pattern              = "processed/{date}/{time}"  # Organizes files by date/time
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"
  batch_min_rows            = 0
  batch_max_wait_time       = "00:01:00"  # Write every minute

  serialization {
    type            = "Json"
    encoding        = "UTF8"
    format          = "LineSeparated"
  }
}

# OUTPUT 2: High pressure alerts go to alerts container
resource "azurerm_stream_analytics_output_blob" "alert_output" {
  name                      = "alertoutput"
  stream_analytics_job_name = azurerm_stream_analytics_job.ot_processor.name
  resource_group_name       = azurerm_resource_group.ot_poc.name
  storage_account_name      = azurerm_storage_account.data_lake.name
  storage_account_key       = azurerm_storage_account.data_lake.primary_access_key
  storage_container_name    = azurerm_storage_container.alerts.name
  path_pattern              = "alerts/{date}/{time}"
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"
  batch_min_rows            = 0
  batch_max_wait_time       = "00:01:00"

  serialization {
    type            = "Json"
    encoding        = "UTF8"
    format          = "LineSeparated"
  }
}
