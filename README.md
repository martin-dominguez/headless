# headless
Headless code pieces in different lenguajes 

## Notification Daemon for Linux
Creates notifications when a blog post is created or updated
### Requirements
You'll need install in your systems following libraries:
- curl 7.18.0 or newer: used to call to headless API
- jq and its dependencies: used to deal with JSON
- libnotify-bin: used to send notifications

The script will check if all the commands are available in the systems by your user

### How to use
Ensure that you user has permissions to execute the script using bash.

Usage:
```
  notification-daemon-4-linux.sh { start | stop | restart | status }
```
