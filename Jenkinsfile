pipeline {
    agent any

    environment {
        ECR_REGISTRY = '378505040508.dkr.ecr.us-east-1.amazonaws.com'
        IMAGE_NAME   = 'python-redis-counter'
        AWS_REGION   = 'us-east-1'
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Set Environment Variables') {
            steps {
                script {
                    def branch = env.GIT_BRANCH.replaceAll('origin/', '')
                    if (branch == 'test') {
                        env.ENVIRONMENT = 'test'
                        env.NAMESPACE   = 'test'
                        env.REDIS_HOST  = 'redis.test.svc.cluster.local'
                    } else if (branch == 'prod') {
                        env.ENVIRONMENT = 'prod'
                        env.NAMESPACE   = 'prod'
                        env.REDIS_HOST  = 'redis.prod.svc.cluster.local'
                    } else {
                        error "Unsupported branch: ${branch}. Only 'test' and 'prod' are allowed."
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REGISTRY}
                """
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                sh """
                    docker build -t ${IMAGE_NAME} .
                    docker tag ${IMAGE_NAME}:latest ${ECR_REGISTRY}/${IMAGE_NAME}:latest
                    docker push ${ECR_REGISTRY}/${IMAGE_NAME}:latest
                """
            }
        }

        stage('Deploy to EKS') {
            environment {
                KUBECONFIG = credentials('kubeconfig')
            }
            steps {
                sh """
                    mkdir -p kubernetes/${NAMESPACE}

                    sed \\
                        -e "s|<your_ecr_image_url>|${ECR_REGISTRY}/${IMAGE_NAME}:latest|g" \\
                        -e "s|<your_environment>|${ENVIRONMENT}|g" \\
                        -e "s|<redis_service_host>|${REDIS_HOST}|g" \\
                        kubernetes/${NAMESPACE}/deployment.yaml > kubernetes/${NAMESPACE}/deployment-gen.yaml

                    kubectl apply -f kubernetes/namespaces.yaml
                    kubectl apply -n ${NAMESPACE} -f kubernetes/${NAMESPACE}/configmap.yaml

                    if [ -f kubernetes/${NAMESPACE}/redis-deployment.yaml ]; then
                      kubectl apply -n ${NAMESPACE} -f kubernetes/${NAMESPACE}/redis-deployment.yaml
                    fi

                    kubectl apply -n ${NAMESPACE} -f kubernetes/${NAMESPACE}/service.yaml
                    kubectl apply -n ${NAMESPACE} -f kubernetes/${NAMESPACE}/deployment-gen.yaml
                """
            }
        }
    }

    post {
        success { echo '✅ Deployed successfully!' }
        failure { echo '❌ Pipeline failed. Check logs.' }
    }
}

