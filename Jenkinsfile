pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
    disableConcurrentBuilds()
  }

  environment {
    APP_NAME   = 'notes-api'
    AWS_REGION = 'us-east-1'
    ECR_REPO   = 'notes/depos'
    CLUSTER = 'notes-eks'
    TRIVY_DISABLE_VEX_NOTICE = 'true'
    TRIVY_SKIP_VERSION_CHECK = 'true'

  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          echo "Building ${APP_NAME} #${BUILD_NUMBER} @ ${env.GIT_SHORT}"
        }
      }
    }
    stage('Gitleaks Secret Scan') {
      steps {
        sh '''
          mkdir -p reports
          gitleaks detect --source . --config .gitleaks.toml \
            --report-format json --report-path reports/gitleaks.json \
            --redact --exit-code 1
        '''
      }
    }

    stage('Install & Unit Test') {
      steps {
        sh 'node --version'
        sh 'npm ci'
        sh 'npm test'
      }
    }
    stage('Dependency Scan') {
      steps {
        sh '''
          mkdir -p reports
          npm audit --omit=dev --audit-level=high
        '''
        sh '''
          trivy fs --scanners vuln,secret,misconfig \
            --severity HIGH,CRITICAL --exit-code 1 \
            --format table --output reports/trivy-fs.txt .
          cat reports/trivy-fs.txt
        '''
      }
    }
    
    
    stage('SonarQube Scan') {
      steps {
        script {
          def scannerHome = tool 'sonar-scanner'
          withSonarQubeEnv('sonarqube') {
            sh "${scannerHome}/bin/sonar-scanner"
          }
        }
      }
    }


    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }
        stage('Hadolint') {
      steps {
        sh '''
          mkdir -p reports
          hadolint --failure-threshold warning Dockerfile | tee reports/hadolint.txt
        '''
      }
    }

    stage('Docker Build') {
      steps {
        script {
          env.ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
          env.REGISTRY   = "${env.ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
          env.IMAGE_TAG  = "${BUILD_NUMBER}-${env.GIT_SHORT}"
          env.IMAGE      = "${env.REGISTRY}/${ECR_REPO}:${env.IMAGE_TAG}"
        }
        sh 'docker build -t "$IMAGE" .'
      }
    }

    stage('Trivy Image Scan') {
      steps {
        sh '''
          mkdir -p reports
          trivy image --scanners vuln,secret --severity HIGH,CRITICAL \
            --format table --output reports/trivy-image.txt "$IMAGE"
          cat reports/trivy-image.txt
          trivy image --scanners vuln,secret --severity CRITICAL \
            --ignore-unfixed --exit-code 1 "$IMAGE"
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region "$AWS_REGION" | \
            docker login --username AWS --password-stdin "$REGISTRY"
          docker push "$IMAGE"
        '''
      }
    }
        stage('Deploy to EKS') {
      steps {
        sh '''
          aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER"
          kubectl apply -f k8s/namespace.yaml
          kubectl apply -f k8s/serviceaccount.yaml
          kubectl apply -f k8s/networkpolicy.yaml
          kubectl apply -f k8s/service.yaml
          sed "s|ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/notes/depos:IMAGE_TAG|$IMAGE|" k8s/deployment.yaml | kubectl apply -f -
        '''
      }
    }

    stage('Verify Rollout') {
      steps {
        sh 'kubectl -n notes rollout status deployment/notes-api --timeout=180s'
      }
      post {
        failure {
          sh '''
            echo "Rollout failed, rolling back"
            kubectl -n notes rollout undo deployment/notes-api
            kubectl -n notes rollout status deployment/notes-api --timeout=120s
          '''
        }
      }
    }
        stage('OWASP ZAP Baseline') {
      steps {
        script {
          env.APP_URL = sh(script: "kubectl -n notes get svc notes-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()
        }
        sh '''
          mkdir -p reports && chmod 777 reports
          docker run --rm -v "$PWD/reports:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
            zap-baseline.py -t "http://$APP_URL" -r zap-report.html -I
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'coverage/** , reports/**', allowEmptyArchive: true
      sh 'docker rmi "$IMAGE" || true'
      sh 'docker logout "$REGISTRY" || true'
      sh 'docker image prune -f || true'
      
    }
    success { echo "Deployed ${env.IMAGE} to EKS" }
    failure { echo "Pipeline failed at ${env.STAGE_NAME}" }
  }
}