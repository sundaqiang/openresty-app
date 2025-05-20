#!/bin/bash
export APP_ENV=development
openresty -p $PWD -c conf/nginx.conf
