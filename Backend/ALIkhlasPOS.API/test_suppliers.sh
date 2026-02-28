#!/bin/bash
TOKEN=$(curl -s -X POST http://localhost:5290/api/auth/login -H "Content-Type: application/json" -d '{"username":"admin","password":"password"}' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
curl -s -X GET http://localhost:5290/api/erp/suppliers -H "Authorization: Bearer $TOKEN"
