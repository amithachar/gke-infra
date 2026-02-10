resource "google_container_cluster" "gke" {
  name     = "ott-cluster"
  location = var.zone   # 🔥 Use zone, not region

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "ott-node-pool"
  location = var.zone   # 🔥 Zonal
  cluster  = google_container_cluster.gke.name

  node_config {
    machine_type = "e2-micro"
    disk_type    = "pd-standard"
    disk_size_gb = 10

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  node_count = 1
}
