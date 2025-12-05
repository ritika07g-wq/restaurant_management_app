pipeline {
    agent any

    environment {
        IMAGE = "ritikagirish123/flutter_restaurant_app"   // Your DockerHub image name
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/ritika07g-wq/restaurant_management_app.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t $IMAGE .'
                }
            }
        }

        stage('Login & Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub_creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh'''
                       echo "$PASS" | docker login -u "$USER" --password-stdin
                       docker push $IMAGE
                    '''
                }
            }
        }
    }
}
