locals {
  timestamp = "${timestamp()}"
  timestamp_sanitized = "${replace("${local.timestamp}","/[- TZ:]/", "")}"
}

################ ******************** Create a regional persistent disk ******************** ###########
resource "google_compute_region_disk" "regiondisk" {
  name                      = "${var.vendor_name}-vm-${var.vm_type}-attached-regional-disk"
  type                      = "pd-ssd"
  # image                     = "rhel-7-v20220719"
  # source_disk               = google_compute_disk.gce_persistent_disk.id
  region                    = "us-central1"
  project                   = var.project_id
  labels                    = var.labels
  # snapshot                  = google_compute_snapshot.name.id
  # source_disk_id = google_compute_disk.gce_persistent_disk[countt.index].id

  replica_zones = var.mig_zones
}

################ ******************** Create a snapshot policy ******************** ###########
resource "google_compute_resource_policy" "policy" {
  name = "my-resource-policy"
  region = "us-central1"
  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time = "04:00"
      }
    }
  }
}

################ ******************** Attach a snapshot policy to regional persistent disk created ******************** ###########
resource "google_compute_region_disk_resource_policy_attachment" "attachment" {
  name = google_compute_resource_policy.policy.name
  disk = google_compute_region_disk.regiondisk.name 
  region = "us-central1"
}

################ ******************** Instance template creation with regional persistent disk ******************** ###########
resource "google_compute_instance_template" "default" {
  count = length(var.vm_ip_list)
  name = "${var.vendor_name}-vm-${var.vm_type}-${count.index+1}-template-${local.timestamp_sanitized}"
  description = "This template is used to create rhel linux instances."
  instance_description = "change in description to test"
  project = var.project_id
  machine_type = var.machine_type
  region       = "us-central1"
  tags = ["allow-https"]

  labels = var.labels

  can_ip_forward       = false

  // Create a new boot disk from an image
  disk {
    source_image      = var.image
    disk_type = var.disk_type
    disk_size_gb = var.size
    type = "PERSISTENT"
    mode = "READ_WRITE"
    auto_delete       = true
    boot              = true
  }

  # //attcahed disk
  # disk {
  #   source_image = "rhel-7-v20220719"
  #   disk_type = var.disk_type
  #   disk_size_gb = var.attached_disk_size
  #   labels = var.labels
  #   type = "PERSISTENT"
  #   mode = "READ_WRITE"
  #   # disk_name = "${var.vendor_name}-vm-${var.vm_type}-${count.index+1}-attached-disk"
  #   auto_delete       = false
  #   boot              = false
  # }

  disk {
    source      = google_compute_region_disk.regiondisk.self_link    
    type        = "PERSISTENT"
    mode        = "READ_ONLY"
    auto_delete = false
    boot        = false
  }
  
  scheduling {
    on_host_maintenance = var.on_host_maintenance
    automatic_restart = var.automatic_restart
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  lifecycle {
    create_before_destroy = true
  }

  network_interface {
    network = "test-vpc"
    subnetwork = "projects/burner-pavgurra/regions/us-central1/subnetworks/test-vpc-subnet-1"
    # network_ip = var.vm_ip_list[each.value]
  }


  metadata = {
    "startup-script" = "${file("${path.module}/tools.sh")}"
    "shutdown-script" = file("${path.module}/shutdown-script.sh")
  }
}

################ ******************** Create mig using instance template ******************** ###########
resource "google_compute_region_instance_group_manager" "regional_mig" {
  count = length(var.vm_ip_list)
  name  = "${var.vendor_name}-vm-${var.vm_type}-${count.index+1}-regional-mig-${local.timestamp_sanitized}"
  project = var.project_id
  base_instance_name = "${var.vendor_name}-${var.vm_type}-${count.index+1}-regional-mig-vm"
  region = "us-central1"
  distribution_policy_zones  = ["us-central1-a", "us-central1-f"]
  target_size = 2

  version {
    name = "${var.vendor_name}-vm-${var.vm_type}-${count.index+1}-vm-template-version"
    instance_template = google_compute_instance_template.default[count.index].id
  }

  update_policy {
    type = "PROACTIVE"
    minimal_action = "REPLACE"
    instance_redistribution_type = "NONE"
    max_unavailable_fixed = 2
    max_surge_fixed = 0
    replacement_method = "RECREATE"
  }
  
}

################ ******************** Create vm instances using mig ******************** ###########
resource "google_compute_region_per_instance_config" "regional_test" {
  count = length(var.vm_ip_list)
  region = "us-central1"
  region_instance_group_manager = google_compute_region_instance_group_manager.regional_mig[count.index].name
  name = "${var.vendor_name}-regional-vm-${var.vm_type}-${count.index+1}-${local.timestamp_sanitized}"
  preserved_state {
    metadata = {
      instance_template = google_compute_instance_template.default[count.index].self_link
    }
  }
}
