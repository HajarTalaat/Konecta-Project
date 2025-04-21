pipeline {
    agent any

    environment {
        // ECR repo URL
        ECR_REGISTRY = '378505040508.dkr.ecr.us-east-1.amazonaws.com'
        IMAGE_NAME = 'python-redis-counter'
        AWS_REGION = 'us-east-1'
        // Inject kubeconfig from Jenkins credentials (file)
        KUBECONFIG_CREDENTIAL_ID = 'kubeconfig'
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
                    // Extract branch name to determine environment
                    def branch = env.GIT_BRANCH.replaceAll('origin/', '')
                    if (branch == 'test') {
                        env.ENVIRONMENT = 'test'
                        env.NAMESPACE = 'test'
                        env.REDIS_HOST = 'redis.test.svc.cluster.local'
                    } else if (branch == 'prod') {
                        env.ENVIRONMENT = 'prod'
                        env.NAMESPACE = 'prod'
                        env.REDIS_HOST = 'redis.prod.svc.cluster.local'
                    } else {
                        error "Unsupported branch: ${branch}. Only 'test' and 'prod' are supported."
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region $AWS_REGION | \
                    docker login --username AWS --password-stdin $ECR_REGISTRY
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t $IMAGE_NAME .
                    docker tag $IMAGE_NAME:latest $ECR_REGISTRY/$IMAGE_NAME:latest
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    docker push $ECR_REGISTRY/$IMAGE_NAME:latest
                '''
            }
        }

        stage('Deploy to EKS') {
            environment {
                KUBECONFIG = credentials('kubeconfig') // Reference the kubeconfig file from Jenkins
            }
            steps {
                sh '''
                    # Replace placeholders in manifest files
                    sed "s|<your_ecr_image_url>|$ECR_REGISTRY/$IMAGE_NAME:latest|g; \
                         s|<your_environment>|$ENVIRONMENT|g; \
                         s|<redis_service_host>|$REDIS_HOST|g" \
                         kubernetes/test/deployment.yaml > kubernetes/test/deployment-gen.yaml

                    kubectl apply -f k8s/namespace.yaml
                    kubectl apply -n $NAMESPACE -f k8s/configmap.yaml
                    kubectl apply -n $NAMESPACE -f k8s/redis-deployment.yaml
                    kubectl apply -n $NAMESPACE -f k8s/redis-service.yaml
                    kubectl apply -n $NAMESPACE -f k8s/deployment-gen.yaml
                    kubectl apply -n $NAMESPACE -f k8s/service.yaml
                '''
            }
        }
    }

    post {
        failure {
            echo '❌ Build failed!'
        }
        success {
            echo '✅ Successfully deployed to EKS!'
        }
    }
}

