#!/bin/bash
echo "Iniciando psql em dvdrental..."
sudo service postgresql start
psql -h 127.0.0.1 -U postgres -d dvdrental

# Password for user admin: postgres