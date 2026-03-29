#!/bin/bash
docker ps --filter name=runner- --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.RunningFor}}'
