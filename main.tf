terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.69.1"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
  region      = var.region
  zone        = var.zone
}

# Create the primary PostgreSQL database
resource "google_sql_database_instance" "primary_db" {
  name                = "primary-db"
  database_version    = "POSTGRES_14"
  deletion_protection = false
  root_password = var.db-pass

  settings {
    tier              = "db-custom-1-3840"
    backup_configuration {
      enabled = true
    }
    ip_configuration {
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }
}

# initialize the pgbench schema on the primary database
resource "null_resource" "create_schema" {
  provisioner "local-exec" {
    command = <<EOF
      export PGPASSWORD=${google_sql_database_instance.primary_db.root_password}
      pgbench -i -U postgres -h ${google_sql_database_instance.primary_db.ip_address.0.ip_address} -p 5432 -d postgres
    EOF
  }

  depends_on = [google_sql_database_instance.primary_db]
}


# Create the standby PostgreSQL database
resource "google_sql_database_instance" "stand_by_db" {
  name                 = "standby-db"
  database_version     = "POSTGRES_14"
  deletion_protection  = false
  master_instance_name = "${var.project}:${google_sql_database_instance.primary_db.name}"
  instance_type        = "READ_REPLICA_INSTANCE"
  root_password = var.db-pass
  

  settings {
    tier              = "db-custom-1-3840"

    backup_configuration {
      enabled    = false
    }

    ip_configuration {
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }

  replica_configuration {
    failover_target = false
  }

  # Backup cron job
  provisioner "local-exec" {
    command = <<EOF
      echo "0 2 * * * export PGPASSWORD=${google_sql_database_instance.primary_db.root_password} && pg_dump -h ${google_sql_database_instance.stand_by_db.ip_address.0.ip_address} -U postgres -d postgres -f /tmp/backup.sql && gsutil cp /tmp/backup.sql gs://${google_storage_bucket.database_backup.name}/$(date +%Y-%m-%d)-backup.sql && rm /tmp/backup.sql" > backup.cron
      crontab backup.cron
      rm backup.cron
    EOF
  }
}

# Create the Cloud Storage bucket for backups
resource "google_storage_bucket" "database_backup" {
  name     = "${var.project}_database_backup"
  location = var.region
  force_destroy = true
  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 15
    }
    action {
      type = "Delete"
    }
  }
}


# Create alert policies for CPU usage on primary database
resource "google_monitoring_alert_policy" "cpu_usage_alert" {
  display_name = "CPU Usage Alert"
  combiner     = "OR"

  conditions {
    display_name = "High CPU Usage"
    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" resource.type=\"cloudsql_database\" resource.label.database_id=\"${var.project}:${google_sql_database_instance.primary_db.name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.9
      trigger {
        count = 1
      }
    }
  }
}

# Create alert policies for Disk usage on primary database
resource "google_monitoring_alert_policy" "disk_usage_alert" {
  display_name = "Disk Usage Alert"
  combiner     = "OR"

  conditions {
    display_name = "High Disk Usage"
    condition_threshold {
      filter = "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" resource.type=\"cloudsql_database\" resource.label.database_id=\"${var.project}:${google_sql_database_instance.primary_db.name}\""

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      trigger {
        count = 1
      }
    }
  }
}
