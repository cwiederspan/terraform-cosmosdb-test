terraform {
  required_version = ">= 0.12"
}

provider "azurerm" {
  version = "~> 2.8"
  features {}
}

variable "name_prefix" {
  type        = string
  description = "A prefix for the naming scheme as part of prefix-base-suffix."
}

variable "name_base" {
  type        = string
  description = "A base for the naming scheme as part of prefix-base-suffix."
}

variable "name_suffix" {
  type        = string
  description = "A suffix for the naming scheme as part of prefix-base-suffix."
}

variable "location" {
  type        = string
  description = "The Azure region where the primary resources will be created."
}

variable "location_backup" {
  type        = string
  description = "The Azure region where the geo-redundant database resource will be created."
}

variable "ru_count" {
  type        = string
  description = "The amount of RUs to provision for the CosmosDB."
}

locals {
  base_name = "${var.name_prefix}-${var.name_base}-${var.name_suffix}"
}

resource "azurerm_resource_group" "rg" {
  name     = local.base_name
  location = var.location
}

resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "${local.base_name}-cosmos"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "MongoDB"
  
  enable_automatic_failover       = true
  enable_multiple_write_locations = true
  
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    prefix            = "${local.base_name}-db-${var.location}"
    location          = var.location
    failover_priority = 0
  }

  geo_location {
    prefix            = "${local.base_name}-db-${var.location_backup}"
    location          = var.location_backup
    failover_priority = 1
  }
}

resource "azurerm_cosmosdb_mongo_database" "db" {
  name                = "${local.base_name}-db"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = var.ru_count
}