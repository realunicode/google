#!/bin/bash

echo "Starting 2-minute Google request demo..."

end=$((SECONDS+120))
while [ $SECONDS -lt $end ]; do
    curl -s -o /dev/null -w "%{http_code}\n" https://www.google.com
    sleep 5
done

echo "Demo finished."
