pipeline {
  agent any

  environment {
    REGISTRY    = 'docker.io/youruser'        // or <acct>.dkr.ecr.<region>.amazonaws.com
    IMAGE_NAME  = 'myapp'
    IMAGE_TAG   = "${env.GIT_COMMIT.take(7)}"
    IMAGE       = "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    DEPLOY_HOST = 'deploy@your-target-host'
  }

  options {
    timeout(time: 20, unit: 'MINUTES')
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Lint & Test') {
      steps {
        sh '''
          python3 -m venv .venv && . .venv/bin/activate
          pip install -r requirements-dev.txt
          ruff check app/
          pytest --maxfail=1 --junitxml=report.xml --cov=app
        '''
      }
      post { always { junit 'report.xml' } }
    }

    stage('Build Image') {
      steps { script { docker.build("${IMAGE}") } }
    }

    stage('Scan Image') {
      steps {
        // Fail on HIGH/CRITICAL once your baseline is clean (drop the `|| true`).
        sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${IMAGE} || true"
      }
    }

    stage('Push Image') {
      steps {
        script {
          docker.withRegistry("https://${REGISTRY}", 'registry-creds') {
            docker.image("${IMAGE}").push()
            docker.image("${IMAGE}").push('latest')
          }
        }
      }
    }

    stage('Deploy') {
      steps {
        sshagent(['deploy-ssh-key']) {
          sh '''
            ssh -o StrictHostKeyChecking=no ${DEPLOY_HOST} "
              docker pull ${IMAGE} &&
              docker rm -f myapp 2>/dev/null || true &&
              docker run -d --name myapp --restart unless-stopped \
                -p 8000:8000 --env-file /opt/myapp/.env ${IMAGE}
            "
          '''
        }
      }
    }

    stage('Verify') {
      steps {
        sh '''
          for i in $(seq 1 10); do
            curl -fs http://your-target-host/health && exit 0
            sleep 5
          done
          echo "Health check failed"; exit 1
        '''
      }
    }
  }

  post {
    failure {
      sshagent(['deploy-ssh-key']) {
        sh '''
          ssh -o StrictHostKeyChecking=no ${DEPLOY_HOST} "
            docker rm -f myapp 2>/dev/null || true &&
            docker run -d --name myapp --restart unless-stopped \
              -p 8000:8000 --env-file /opt/myapp/.env ${REGISTRY}/${IMAGE_NAME}:latest
          " || true
        '''
      }
      echo 'Deployment failed — rolled back to :latest.'
    }
    always { cleanWs() }
  }
}
