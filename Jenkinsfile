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
        GCP_KEY = credentials('gcp-service-account')
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
                        echo '${GCP_KEY}' > key.json
                        export GOOGLE_APPLICATION_CREDENTIALS=key.json
                        terraform init
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
                        export GOOGLE_APPLICATION_CREDENTIALS=key.json
                        terraform apply -auto-approve \
                        -var="project_id=${PROJECT_ID}" \
                        -var="region=${REGION}" \
                        -var="zone=${ZONE}"
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
                        export GOOGLE_APPLICATION_CREDENTIALS=key.json
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
