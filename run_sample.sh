#!/bin/bash

curl http://localhost:8080/pipelines/user_defined_pipelines/car_plate_recognition_1 -X POST -H 'Content-Type: application/json' -d ' 
{
    "source": {
        "uri": "file:///home/pipeline-server/videos/cars_extended.mp4", 
        "type": "uri"
    },
    "destination": {
        "metadata": {
            "type": "mqtt",
            "host": "172.31.233.38:1883", 
            "topic": "object_detection_1",
            "timeout": 1000
        },
        "frame": {
            "type": "webrtc",
            "peer-id": "object_detection_1"
        }
    },
    "parameters": {
        "detection-device": "CPU"
    }
}'

