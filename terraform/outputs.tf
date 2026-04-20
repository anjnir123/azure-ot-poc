# These values are printed after "terraform apply" completes
# You will need some of these for the next steps

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.ot_poc.name
}

output "iot_hub_name" {
  description = "Name of the IoT Hub"
  value       = azurerm_iothub.ot_hub.name
}

output "iot_hub_hostname" {
  description = "IoT Hub hostname (used for device connections)"
  value       = azurerm_iothub.ot_hub.hostname
}

output "storage_account_name" {
  description = "Storage account name for processed sensor data"
  value       = azurerm_storage_account.data_lake.name
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.secrets.name
}

output "key_vault_uri" {
  description = "Key Vault URI - used by Python simulator to fetch secrets"
  value       = azurerm_key_vault.secrets.vault_uri
}

output "stream_analytics_job_name" {
  description = "Stream Analytics job name"
  value       = azurerm_stream_analytics_job.ot_processor.name
}

output "next_steps" {
  description = "What to do after terraform apply"
  value = <<-EOT
  ============================================================
  TERRAFORM APPLY COMPLETE - NEXT STEPS:
  ============================================================
  1. Register your IoT device:
     az iot hub device-identity create \
       --device-id wellhead-TX-001 \
       --hub-name ${azurerm_iothub.ot_hub.name}

  2. Get the device connection string:
     az iot hub device-identity connection-string show \
       --device-id wellhead-TX-001 \
       --hub-name ${azurerm_iothub.ot_hub.name} \
       --query connectionString -o tsv

  3. Update Key Vault secret with the real connection string:
     az keyvault secret set \
       --vault-name ${azurerm_key_vault.secrets.name} \
       --name iothub-device-connection-string \
       --value "YOUR_CONNECTION_STRING_HERE"

  4. Start the Stream Analytics job:
     az stream-analytics job start \
       --name ${azurerm_stream_analytics_job.ot_processor.name} \
       --resource-group ${azurerm_resource_group.ot_poc.name} \
       --output-start-mode JobStartTime

  5. Run the sensor simulator:
     cd ../simulator
     pip install -r requirements.txt
     python sensor_simulator.py
  EOT
}
