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
        GCP_CREDENTIALS = credentials('gcp-service-account')
        PROJECT_ID = "project-3a9d1629-f247-457c-ae4"
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
                    echo $GCP_CREDENTIALS > gcp-key.json
                    export GOOGLE_APPLICATION_CREDENTIALS=gcp-key.json
                    terraform init
                    """
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh """
                    export GOOGLE_APPLICATION_CREDENTIALS=gcp-key.json
                    terraform plan -var="project_id=${PROJECT_ID}"
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
                    export GOOGLE_APPLICATION_CREDENTIALS=gcp-key.json
                    terraform apply -auto-approve -var="project_id=${PROJECT_ID}"
                    """
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                dir("${TF_DIR}") {
                    sh """
                    export GOOGLE_APPLICATION_CREDENTIALS=gcp-key.json
                    terraform destroy -auto-approve -var="project_id=${PROJECT_ID}"
                    """
                }
            }
        }
    }
}
