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

    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'coverage/** , reports/**', allowEmptyArchive: true
    }
  }
}