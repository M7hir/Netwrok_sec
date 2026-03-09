#!/bin/bash

sudo python run.py --node S4 --cmd "pgrep -f [z]ebra-S4 | xargs kill -9"
sudo python run.py --node S4 --cmd "pgrep -f [b]gpd-S4 | xargs kill -9"
