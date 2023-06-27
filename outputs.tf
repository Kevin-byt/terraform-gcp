output "primary_db" {
  value = google_sql_database_instance.primary_db.ip_address.0.ip_address
}

output "standby_db" {
  value = google_sql_database_instance.stand_by_db.ip_address.0.ip_address
}

output "storage" {
  value = google_storage_bucket.database_backup.name
}