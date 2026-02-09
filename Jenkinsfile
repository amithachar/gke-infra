pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose Terraform action'
        )
    }

    environment {
        TF_DIR = "terraform"
        PROJECT_ID = "project-3a9d1629-f247-457c-ae4"
        REGION = "us-central1"
        ZONE = "us-central1-a"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${TF_DIR}") {
                    sh """
                        terraform init
                    """
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir("${TF_DIR}") {
                    sh "terraform validate"
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir("${TF_DIR}") {
                    sh """
                        terraform plan \
                        -var="project_id=${PROJECT_ID}" \
                        -var="region=${REGION}" \
                        -var="zone=${ZONE}"
                    """
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh """
                        terraform apply -auto-approve \
                        -var="project_id=${PROJECT_ID}" \
                        -var="region=${REGION}" \
                        -var="zone=${ZONE}"
                    """
                }
            }
        }

        stage('Approval Before Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                input message: "Are you sure you want to DESTROY the GKE cluster?"
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh """
                        terraform destroy -auto-approve \
                        -var="project_id=${PROJECT_ID}" \
                        -var="region=${REGION}" \
                        -var="zone=${ZONE}"
                    """
                }
            }
        }
    }
}
