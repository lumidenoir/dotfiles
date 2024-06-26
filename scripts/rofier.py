#!/usr/bin/env python3

import subprocess
import json

output = subprocess.getoutput("dunstctl history")
history = json.loads(output)

message_list = history["data"][0]
# loop list
for message in message_list:
    print("\x00markup-rows\x1ftrue")
    print(message["message"]["data"].replace('\n', '\r'))
