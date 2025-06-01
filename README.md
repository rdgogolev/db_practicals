# Library Management System

This project is a small Flask application that exposes an endpoint to list books from a PostgreSQL database.<br>
These instructions assume you’re starting on Linux/macOS machine.

## 1. Prerequisites

- **Python 3.8+** (with `venv` support)
- **Git** (if you’re cloning from a repository)
- **PostgreSQL 13+** (server + client tools)
---

## Step by step guid

First of all clone the repositroy and go to the folder <br>
```
git clone <repository link>
cd db_practicals/library-management-task
```
activate the virtual environment
```
source myenv/bin/activate 
```
check if the postgresql active or not
```
sudo systemctl status postgresql
```
if not, then do this
```
sudo systemctl start postgresql
sudo systemctl enable postgresql
```
after this we can check the status again and see that it is active, <br>
run the postgres, add password on it, create the library_db database and exit 
```
sudo -u postgres psql
ALTER USER postgres WITH PASSWORD 'qwerty';
CREATE DATABASE library_db OWNER postgres;
\q
```
we need also to add tables and initilaize them
```
sudo -u postgres psql -d library_db -f schema.sql
sudo -u postgres psql -d library_db -f data.sql
```
if you want to check you can open the database 
```
psql -U postgres -h localhost -d library_db
```
and select all books
```
SELECT * FROM book;
```
or run curl command to get the data
```
curl http://localhost:5000/api/list
```
