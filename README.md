# provision-gce-vm
Create and provision an GCP compute engine VM instance using Terraform resources with below features combined &amp; integrated as a one. Regional Persistent disk Disk snapshot Snapshot schedule policy Instance template Regional Managed Instance Group Per instance configuration

Below are the sequence of steps will be performed through Terraform resources
1. Create a Regional persistent disk. This is different to Zonal disk as Regional disk benefits in high availability of disk across multiple zones
2. Capture a snapshot of above created Regional persistent disk. Snapshots benefits in backing up data from your persistent disks and can be used to restore data to a new disk or instance within the same project
3. Create snapshot schedule and attach it to disk. Backing up your disks regularly with scheduled snapshots can reduce the risk of unexpected data loss.
4. Instance template which is used to create virtual machine (VM) instances and managed instance groups (MIGs). Instance templates are a convenient way to save a VM instance's configuration so you can use it later to create VMs or groups of VMs.
5. Create Regional MIG using Instance template. Regional MIG that spreads its VMs across multiple zones in a region. Regional MIG helps in increase the resilience of your MIG-based workload.
6. A config defined for a single managed instance that belongs to an instance group manager.
7. Finally provision VM instances with above features integrated
