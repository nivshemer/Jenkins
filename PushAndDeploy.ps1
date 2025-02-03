if [ "$DEPLOY_TO_DEV_MD_ENV" = "true" ]; then
    echo "-------- Deploying to DEV environment --------"
    
    cd /nanolock/deployment-scripts/ || exit 1

    sed -i "s/^CONTAINER_TAG=.*/CONTAINER_TAG=$VERSION/" .env || exit 1

    docker-compose up -d

    docker image prune -a --force
    docker system prune --force
fi
