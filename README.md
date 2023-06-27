Server Requirements
- Install terraform
- Install POSTGRES_14 or higher and the postgresql-contrib packages
- Cron service running

Running the template
- Within the folder that houses main.tf, variables.tf and outputs.tf, run the following:
    - terraform init - initializes the backend and provider plugins
    - terraform plan - shows the resources to be created
    - terraform apply - creates the resources

This terraform configuration creates cloud resources on google cloud and includes the following files:
      1. main.tf - contains the resources created
      2. variables.tf - contains the values to the variable names used within the template
      3. outputs.tf - Lists the terminal output after successful deployment of resources

1. main.tf
- The terraform template creates respurces on google gloud using version 4.69.1
- The sections of the main.tf include:

a. provider
- The provider loads the credentials file(not shared as is confidential). Each google cloud account should have it's own secret credentials file
- It sets the project on google cloud. The project variable is set in the variables.tf file(terraform-project-390319)
- Sets the region to deploy the resources - The region variable is set in the variables.tf file(us-central1)
- Sets the zone to deploy the resources- The zone variable is set in the variables.tf file(us-centralc)

b. Google SQL Database instances
- Consists of 2 postgres-14 databases: primary-db and standby-db
- The primary-db is the primary database and the standby-db acts as a replica db for the primary database
- Both instances are configured with instances with 1 vcpu and 3840MB of memory
- Connection from everywhere(0.0.0.0/0) is allowed for this exercise. In a production scenario, the authorized networks should be within an organizational whitelist

c. create schema script
- The script initializes the primary database with the pgbench schema
- The script run on the server that hosts the terraform template and requires an equal or higher version of postgres to run
- The script runs after the primary database is created

g. Google cloud storage bucket
- The bucket is used to store the database backups
- The objects stored in the bucket are deleted after 15 days

e. Backup cron
- The backup cron creates a cronjob to create a database backup from the standy database and upload it to the storage bucket. The cron runs on the server that hosts and runs the terraform template
- The database backup uses the "(date +%Y-%m-%d)-backup.sql" naming convention. For example, the database backup file for 28th June 2023 would be named: "2023-06-28-backup.sql"
- The cron job runs daily at 02:00 HRS

f. Monitoring policies
- There are 2 monitoring policies:
i. The cpu_usage_alert - monitors when the cpu utilization metric goes above 90% for 5 minutes(300s) or more on the primary database and creates an alert on the dashboard

ii. The disk_usage_alert - monitors when the disk utilization metric goes above 85% for 5 minutes(300s) or more on the primary database and creates an alert on the dashboard


2. variables.tf
- Sets the values for project, credentials file, region, zone and password to be used when creating the resources

3. outputs.tf
- Prints out the primary database's public ip address, the standby database's public ip address and the storage bucket name after a successful deployment or refresh

More information on the configuration can be found on the official terraform documentation for GCP found at: https://registry.terraform.io/providers/hashicorp/google/latest/docs
