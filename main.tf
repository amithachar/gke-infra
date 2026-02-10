resource "google_container_cluster" "gke" {
  name     = "ott-cluster"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "ott-node-pool"
  location = var.region
  cluster  = google_container_cluster.gke.name

  node_config {
    machine_type = "e2-micro"   # 🔥 smallest possible
    disk_type    = "pd-standard"  # 🔥 NOT SSD
    disk_size_gb = 10            # 🔥 minimal disk

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  node_count = 1
}
