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

    stage('Install & Unit Test') {
      steps {
        sh 'node --version'
        sh 'npm ci'
        sh 'npm test'
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'coverage/**', allowEmptyArchive: true
    }
  }
}