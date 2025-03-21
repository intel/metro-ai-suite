# Rapid_RI
## Setup Instructions

1. Modify the `HOST_IP` variable in the `.env` file to your actual host IP address.
2. Execute the `update_dashboard.sh` script to adjust all config files based on the device IP.
3. Execute the `install.sh` script to download the required models and videos.
4. These 4 steps need to be done for the first time setup and whenever a new commit is pulled.

## Deployment

1. Start the microservice using one of the following commands:
   - `make start`
2. Access the application at [http://localhost:3000](http://localhost:3000) (for local use) or [http://<actual_ip>:3000](http://<actual_ip>:3000) (for external access).
3. Log in with the following credentials:
   - **Username:** `admin`
   - **Password:** `admin`
4. To stop the microservice, using one of the following commands:
   - `make stop`

## Pipeline Example

1. Execute run_sample.sh.

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


