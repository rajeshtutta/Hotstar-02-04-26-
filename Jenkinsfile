pipeline {
    agent any

    tools {
        maven 'maven3'
        jdk 'jdk21'
    }

    environment {
        // SonarQube Jenkins server configuration name
        SONARQUBE_ENV = 'sq'

        // AWS
        AWS_DEFAULT_REGION = 'ap-south-1'

        // ECR
        ECR_REGISTRY = '379367335704.dkr.ecr.ap-south-1.amazonaws.com'
        ECR_REPOSITORY = 'hotstar'

        // Docker image
        DOCKER_IMAGE = "${ECR_REGISTRY}/${ECR_REPOSITORY}"

        // EKS
        EKS_CLUSTER = 'mycluster'

        // AWS Jenkins credential
        AWS_CREDS = credentials('aws_creds')

        // Email
        RECIPIENTS = 'rajeshtutta123@gmail.com'
    }

    stages {

        /*
         * 1. CHECKOUT
         */
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/rajeshtutta/Hotstar-02-04-26-.git'
            }
        }

        /*
         * 2. CHECK JAVA + MAVEN
         */
        stage('Verify Tools') {
            steps {
                sh '''
                    echo "========== JAVA VERSION =========="
                    java -version

                    echo "========== MAVEN VERSION =========="
                    mvn -version

                    echo "========== AWS VERSION =========="
                    aws --version

                    echo "========== DOCKER VERSION =========="
                    docker --version

                    echo "========== KUBECTL VERSION =========="
                    kubectl version --client
                '''
            }
        }

        /*
         * 3. BUILD APPLICATION
         */
        stage('Maven Build') {
            steps {
                sh '''
                    mvn clean package -DskipTests
                '''
            }
        }

        stage('Check Plexus Dependency') {
    steps {
        withMaven(
            jdk: 'jdk21',
            maven: 'maven3',
            mavenSettingsConfig: 'nexus-settings'
        ) {
            sh '''
                echo "========== PLEXUS DEPENDENCY =========="
                mvn dependency:tree -Dincludes=org.codehaus.plexus:plexus-utils
            '''
        }
    }
}

        /*
         * 4. UNIT TEST
         */
        stage('Maven Test') {
            steps {
                sh '''
                    mvn test
                '''
            }
        }

        /*
         * 5. SONARQUBE ANALYSIS
         */
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv("${SONARQUBE_ENV}") {
                    sh '''
                        mvn sonar:sonar
                    '''
                }
            }
        }

        /*
         * 6. SONARQUBE QUALITY GATE
         */
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        /*
         * 7. DEPLOY MAVEN ARTIFACT TO NEXUS
         */
        stage('Deploy to Nexus') {
    steps {
        withMaven(
            jdk: 'jdk21',
            maven: 'maven3',
            mavenSettingsConfig: 'nexus-settings',
            traceability: true
        ) {
            sh 'mvn deploy'
        }
    }
}
        /*
         * 8. BUILD DOCKER IMAGE
         */
        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                        -t ${DOCKER_IMAGE}:latest \
                        .
                '''
            }
        }

        /*
         * 9. TRIVY SECURITY SCAN
         */
        stage('Trivy Scan') {
            steps {
                sh '''
                    echo "========== TRIVY IMAGE SCAN =========="

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        ${DOCKER_IMAGE}:latest
                '''
            }
        }

        /*
         * 10. LOGIN TO AWS ECR
         */
        stage('Login to ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws_creds',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                        aws ecr get-login-password \
                            --region ${AWS_DEFAULT_REGION} |
                        docker login \
                            --username AWS \
                            --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }

        /*
         * 11. TAG DOCKER IMAGE
         */
        stage('Tag Docker Image') {
            steps {
                sh '''
                    docker tag \
                        ${DOCKER_IMAGE}:latest \
                        ${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}

                    docker tag \
                        ${DOCKER_IMAGE}:latest \
                        ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                '''
            }
        }

        /*
         * 12. PUSH IMAGE TO ECR
         */
        stage('Push Image to ECR') {
            steps {
                sh '''
                    docker push \
                        ${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}

                    docker push \
                        ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                '''
            }
        }

        stage('Install eksctl') {
    steps {
        sh '''
            set -e

            if command -v eksctl > /dev/null 2>&1
            then
                echo "eksctl is already installed."
                eksctl version
            else
                echo "Installing eksctl..."

                curl --silent --location \
                    "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
                    | tar xz -C /tmp

                mkdir -p $HOME/bin
                mv /tmp/eksctl $HOME/bin/eksctl

                export PATH=$HOME/bin:$PATH

                echo "eksctl installed successfully."
                eksctl version
            fi
        '''
    }
}

             /*
 * 13. CREATE / VERIFY EKS CLUSTER
 */
stage('Create / Verify EKS Cluster') {

    options {
        timeout(time: 30, unit: 'MINUTES')
    }

    steps {

        withCredentials([
            usernamePassword(
                credentialsId: 'aws_creds',
                usernameVariable: 'AWS_ACCESS_KEY_ID',
                passwordVariable: 'AWS_SECRET_ACCESS_KEY'
            )
        ]) {

            sh '''
                set -e

                echo "========================================="
                echo "       CHECKING EKS CLUSTER"
                echo "========================================="

                if aws eks describe-cluster \
                    --region ${AWS_DEFAULT_REGION} \
                    --name ${EKS_CLUSTER} > /dev/null 2>&1
                then
                    echo "EKS cluster ${EKS_CLUSTER} already exists."
                    echo "Skipping cluster creation."

                else
                    echo "EKS cluster ${EKS_CLUSTER} does not exist."
                    echo "Creating EKS cluster..."

                    eksctl create cluster \
                        --name ${EKS_CLUSTER} \
                        --region ${AWS_DEFAULT_REGION} \
                        --nodes 2 \
                        --node-type t3.medium \
                        --managed

                    echo "EKS cluster creation completed."
                fi

                echo ""
                echo "Verifying EKS cluster..."

                aws eks describe-cluster \
                    --region ${AWS_DEFAULT_REGION} \
                    --name ${EKS_CLUSTER} \
                    --query 'cluster.status' \
                    --output text
            '''
        }
    }
}

        /*
         * 13. DEPLOY TO EKS
         */
        stage('Deploy to EKS') {

            options {
                timeout(time: 30, unit: 'MINUTES')
            }

            steps {

                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws_creds',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "========================================="
                        echo "        DEPLOYING APPLICATION TO EKS"
                        echo "========================================="

                        echo "AWS Region       : ${AWS_DEFAULT_REGION}"
                        echo "EKS Cluster      : ${EKS_CLUSTER}"
                        echo "ECR Registry     : ${ECR_REGISTRY}"
                        echo "ECR Repository   : ${ECR_REPOSITORY}"
                        echo "Image Tag        : ${BUILD_NUMBER}"

                        echo ""
                        echo "Updating kubeconfig..."

                        aws eks update-kubeconfig \
                            --region ${AWS_DEFAULT_REGION} \
                            --name ${EKS_CLUSTER}

                        echo "Kubeconfig updated successfully."

                        echo ""
                        echo "Checking Kubernetes cluster..."

                        kubectl get nodes

                        echo ""
                        echo "Updating deployment image..."

                        kubectl set image deployment/hotstar \
                            hotstar=${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}

                        echo ""
                        echo "Applying Kubernetes configuration..."

                        kubectl apply -f deployment.yml
                        kubectl apply -f service.yml

                        echo ""
                        echo "Checking deployment rollout..."

                        kubectl rollout status deployment/hotstar \
                            --timeout=10m

                        echo ""
                        echo "Checking pods..."

                        kubectl get pods

                        echo ""
                        echo "Checking services..."

                        kubectl get services

                        echo ""
                        echo "========================================="
                        echo "       EKS DEPLOYMENT SUCCESSFUL"
                        echo "========================================="
                    '''
                }
            }
        }

    }   // ✅ closes stages


    /*
     * EMAIL NOTIFICATION
     */
    post {

        success {

            emailext(
                subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",

                body: """
Build Successful!

=========================================
JENKINS BUILD DETAILS
=========================================

Job Name:
${env.JOB_NAME}

Build Number:
${env.BUILD_NUMBER}

Docker Image:
${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.BUILD_NUMBER}

EKS Cluster:
${env.EKS_CLUSTER}

AWS Region:
${env.AWS_DEFAULT_REGION}

Build URL:
${env.BUILD_URL}

=========================================
Deployment completed successfully.
=========================================
""",

                to: "${RECIPIENTS}"
            )
        }


        failure {

            emailext(
                subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",

                body: """
Build Failed!

=========================================
JENKINS BUILD DETAILS
=========================================

Job Name:
${env.JOB_NAME}

Build Number:
${env.BUILD_NUMBER}

Docker Image:
${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${BUILD_NUMBER}

EKS Cluster:
${env.EKS_CLUSTER}

AWS Region:
${env.AWS_DEFAULT_REGION}

Please check Jenkins console output for
the exact error.

Build URL:
${env.BUILD_URL}

=========================================
""",

                to: "${RECIPIENTS}"
            )
        }
    }

}   // ✅ closes pipeline
