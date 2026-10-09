#!/usr/bin/env bash
UP=$(uptime -p 2>/dev/null | sed 's/up //; s/ hours\?,/h/; s/ minutes\?/m/; s/ days\?,/d/')
echo "󰔛 ${UP:-just started}"
