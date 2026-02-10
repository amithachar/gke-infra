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
        PROJECT_ID = "project-3a9d1629-f247-457c-ae4"
        REGION     = "us-central1"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh "terraform init"
            }
        }

        stage('Terraform Validate') {
            steps {
                sh "terraform validate"
            }
        }

        stage('Terraform Plan') {
            steps {
                sh """
                terraform plan \
                -var="project_id=${PROJECT_ID}" \
                -var="region=${REGION}"
                """
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                sh """
                terraform apply -auto-approve \
                -var="project_id=${PROJECT_ID}" \
                -var="region=${REGION}"
                """
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
                sh """
                terraform destroy -auto-approve \
                -var="project_id=${PROJECT_ID}" \
                -var="region=${REGION}"
                """
            }
        }
    }
}
