#!/bin/bash
echo "Starting backend..."
cd backend && npm start &
sleep 2

echo "Starting flutter app..."
cd ../live_tv && flutter run
