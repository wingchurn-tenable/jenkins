pipeline {
  agent any

  environment {
    IMAGE_NAME = 'myapp'
    IMAGE_TAG  = "${env.GIT_COMMIT.take(7)}"
    APP_PORT   = '8000'
    ENV_FILE   = '/opt/myapp/.env'      // optional; used only if it exists
  }

  options {
    timeout(time: 20, unit: 'MINUTES')
    disableConcurrentBuilds()
  }

  stages {
    stage('Lint & Test') {
      steps {
        sh '''
          python3 -m venv .venv && . .venv/bin/activate
          pip install -q -r requirements-dev.txt
          ruff check app/
          pytest --maxfail=1 --junitxml=report.xml --cov=app
        '''
      }
      post { always { junit 'report.xml' } }
    }

    stage('Build Image') {
      steps {
        sh '''
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
        '''
      }
    }

    stage('Scan Image') {
      steps {
        // Fail on HIGH/CRITICAL once your baseline is clean (drop the `|| true`).
        sh 'command -v trivy >/dev/null 2>&1 && trivy image --exit-code 1 --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG} || echo "trivy not installed, skipping scan"'
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          # keep the currently running image as :previous for rollback
          docker image tag ${IMAGE_NAME}:current ${IMAGE_NAME}:previous 2>/dev/null || true
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:current

          ENV_ARG=""
          [ -f "${ENV_FILE}" ] && ENV_ARG="--env-file ${ENV_FILE}"

          docker rm -f ${IMAGE_NAME} 2>/dev/null || true
          docker run -d --name ${IMAGE_NAME} --restart unless-stopped \
            -p ${APP_PORT}:8000 $ENV_ARG ${IMAGE_NAME}:current
        '''
      }
    }

    stage('Verify') {
      steps {
        sh '''
          for i in $(seq 1 10); do
            curl -fs http://localhost:${APP_PORT}/health && echo " OK" && exit 0
            sleep 3
          done
          echo "Health check failed"; exit 1
        '''
      }
    }
  }

  post {
    failure {
      sh '''
        # roll back to the previous image if one exists
        if docker image inspect ${IMAGE_NAME}:previous >/dev/null 2>&1; then
          echo "Rolling back to previous image"
          docker rm -f ${IMAGE_NAME} 2>/dev/null || true
          ENV_ARG=""
          [ -f "${ENV_FILE}" ] && ENV_ARG="--env-file ${ENV_FILE}"
          docker run -d --name ${IMAGE_NAME} --restart unless-stopped \
            -p ${APP_PORT}:8000 $ENV_ARG ${IMAGE_NAME}:previous || true
        fi
      '''
      echo 'Build failed.'
    }
    always { cleanWs() }
  }
}
