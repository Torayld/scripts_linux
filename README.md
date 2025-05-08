# List of script to manage linux
<br><b>wifi_hotspot.sh</b> : Connect to WIFI if not available retry [ and create hotspot if necessary ] can install to systemd
<br><b>usb_toolbox.sh</b> : Auto mount USB SSD Drive and enable TRIM if available, add to fstab or systemd (ex: mount usb drive by systemd before mariadb start with db on usb drive)
<br><b>systemd.sh</b> : Help to create services with systemd
<br><b>crontab.sh</b> : help to create cronjob with param checker
<br><b>manage_ipv6.sh</b> : Can enable or disable IPv6
<br>
<br>
# List of script with function to use with main script
<br><b>copy_file.sh</b> : To handle file copy with compare and confirmation, enable chmod +x on sh file, Copy dependencies of a script to a destination directory
<br><b>update_file.sh</b> : To handle update config file if necessary
<br><b>checker.sh</b> : Checkers for arguments, users, and permissions
<br><b>errors_code.sh</b> : Error Codes and their Meanings
<br><b>network.sh</b> : Function for network operations
<br><b>pid.sh</b> : Functions to lock execution using a PID file

# List of python script
<br><b>button.py</b> : Handler for Nespi4 buttons Change usage of power led, power button, reset button to enable wifi and display wifi mode and shutdown with systemctl
<br><b>fan_ctrl4.py</b> : Handle PWM Fan specially Noctua NF-A4x10 5V PWM with systemctl