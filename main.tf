resource "google_container_cluster" "gke" {
  name     = "ott-gke-cluster"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "ott-node-pool"
  location = var.region
  cluster  = google_container_cluster.gke.name

  node_config {
    machine_type = "e2-medium"

    # 🔥 Reduced disk to avoid SSD quota error
    disk_size_gb = 20

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # 🔥 Reduced node count for dev environment
  node_count = 1
}
