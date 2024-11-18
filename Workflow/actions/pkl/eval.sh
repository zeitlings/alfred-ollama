#!/bin/bash

pkl eval template.pkl # > &dev null ~ 
pkl eval -f json actions.config.pkl -o ../actions.json



