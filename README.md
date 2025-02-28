# Rapid_RI
## Setup Instructions

1. Modify the `HOST_IP` variable in the `.env` file to your actual host IP address.
2. Modify the "Case" variable in the '.env' file to the actual use case(eg. Smart_Parking/Smart_Tolling).
2. Execute the `update_dashboard.sh` script.
3. These 2 steps need to be done for the first time setup and whenever a new commit is pulled.

## Deployment

1. Start the microservice using one of the following commands:
   - `docker-compose up -d`
   - `make start`
2. Access the application at [http://localhost:3000](http://localhost:3000) (for local use) or [http://<actual_ip>:3000](http://<actual_ip>:3000) (for external access).
3. Log in with the following credentials:
   - **Username:** `admin`
   - **Password:** `admin`
4. To stop the microservice, using one of the following commands:
   - `docker-compose down -v`
   - `make stop`

## Pipeline Example

You can trigger a pipeline using the following `curl` command:

```bash
curl http://localhost:8080/pipelines/user_defined_pipelines/yolov5 -X POST -H 'Content-Type: application/json' -d ' 
{
    "source": {
        "uri": "file:///home/pipeline-server/videos/warehouse.avi", 
        "type": "uri"
    },
    "destination": {
        "metadata": {
            "type": "mqtt",
            "host": "<localhost or actual ip>:1883", 
            "topic": "object_detection_cpu_metadata",
            "timeout": 1000
        },
        "frame": {
            "type": "webrtc",
            "peer-id": "object_detection_cpu"
        }
    },
    "parameters": {
        "detection-device": "CPU"
    }
}'
```

## FAQ

1. If unable to deploy grafana container successfully due to fail to GET "https://grafana.com/api/plugins/yesoreyeram-infinity-datasource/versions": context deadline exceeded, please ensure the proxy is configured in the ~/.docker/config.json as shown below:

```bash
         "proxies": {
                "default": {
                        "httpProxy": "<Enter http proxy>",
                        "httpsProxy": "<Enter https proxy>",
                        "noProxy": "<Enter no proxy>"
                }
        }
```

After editing the file, remember to reload and restart docker before deploying the microservice again.

```bash
systemctl daemon-reload
systemctl restart docker
```


