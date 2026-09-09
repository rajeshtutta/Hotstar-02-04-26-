
pipeline {
    agent any

    environment {
        SONARQUBE_ENV = 'sq'
        DOCKER_IMAGE = "rajeshtutta123/rajesh_hotstar-02-04-26"
        AWS_CREDS = credentials('aws_creds')
        AWS_DEFAULT_REGION = 'ap-south-1b'
        RECIPIENTS = 'rajeshtutta123@gmail.com'
    }

    stages {

        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/rajeshtutta/Hotstar-02-04-26-.git'
            }
        }
        stage('BUILD') {
        steps {
            sh 'mvn clean package -DskipTests'
        }
    }
        stage('JENKINS TO NEXUS') {
        steps {
          withMaven(jdk: 'jdk21', maven: 'maven3', traceability: true) {
             sh 'mvn deploy'
}
        }
    }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv("${SONARQUBE_ENV}") {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }


        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE:latest .'
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                    echo $PASS | docker login -u $USER --password-stdin
                    docker push $DOCKER_IMAGE:latest
                    docker logout
                    '''
                }
            }
        }
         stage('Build') {
            steps {
                echo "Building..."
            }
        }

        stage('Test') {
            steps {
                echo "Testing..."
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                export AWS_ACCESS_KEY_ID=$AWS_CREDS_USR
                export AWS_SECRET_ACCESS_KEY=$AWS_CREDS_PSW

                aws eks update-kubeconfig --region us-east-1 --name mycluster
                kubectl apply -f deployment.yml
                kubectl apply -f service.yml
                '''
            }
        }
    }

    post {
        success {
            emailext(
                subject: "Jenkins Job '${env.JOB_NAME}' Success",
                body: "Good news! Job '${env.JOB_NAME}' (#${env.BUILD_NUMBER}) succeeded.\n\nCheck console output at ${env.BUILD_URL}",
                to: "${RECIPIENTS}"
            )
        }

        failure {
            emailext(
                subject: "Jenkins Job '${env.JOB_NAME}' Failed",
                body: "Alert! Job '${env.JOB_NAME}' (#${env.BUILD_NUMBER}) failed.\n\nCheck console output at ${env.BUILD_URL}",
                to: "${RECIPIENTS}"
            )
        }

    }
}
