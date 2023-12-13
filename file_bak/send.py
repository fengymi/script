import sys
import notify

title = sys.argv[1]
content = sys.argv[2]
notify.send(title, content)