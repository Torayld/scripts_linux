#!/usr/bin/python3

# -------------------------------------------------------------------
# Handler for Nespi4 buttons
# Version: 1.0.0
# Date: 2023-10-01
# Author: Torayld
# -------------------------------------------------------------------

import RPi.GPIO as GPIO
import time
import multiprocessing
import subprocess
import os
import signal
import sys
from datetime import datetime

# --- Logging function ---
def log(message):
    if sys.stdout.isatty():
        now = datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
        print(f"{now} {message}")

# --- GPIO Pins ---
wifiOnPin = 3
ledPin = 14
poweroffPin = 2
powerenPin = 4  # not used

# --- Setup GPIO ---
GPIO.setmode(GPIO.BCM)
GPIO.setup(wifiOnPin, GPIO.IN)
GPIO.setup(poweroffPin, GPIO.IN)
GPIO.setup(ledPin, GPIO.OUT)

def get_interface_state(interface):
    try:
        result = subprocess.run(['ifconfig', interface], capture_output=True, text=True)
        if result.returncode != 0:
            log(f"Error : Interface {interface} not found.")
            return None
        return 'UP' if 'UP' in result.stdout else 'DOWN'
    except Exception as e:
        log(f"Error while checkink interface : {e}")
        return None

def get_interface_mode(interface):
    try:
        result = subprocess.run(['iw', interface, 'info'], capture_output=True, text=True)
        if result.returncode != 0:
            log(f"Error : unable to get information from interface {interface}.")
            return None
        for line in result.stdout.splitlines():
            if 'type' in line:
                mode = line.strip().split()[-1]
                return mode
        return None
    except Exception as e:
        log(f"Error while detecting Wi-Fi mode : {e}")
        return None

def handle_wifi_button(stop_event):
    try:
        while not stop_event.is_set():
            state = get_interface_state('wlan0')
            if GPIO.input(wifiOnPin) == GPIO.HIGH:
                log("Wi-Fi ON.")
                if state == 'DOWN':
                    log("Wi-Fi Activated.")
                    subprocess.run(['nmcli', 'radio', 'wifi', 'on'])
            elif GPIO.input(wifiOnPin) == GPIO.LOW:
                log("Wi-Fi OFF.")
                if state == 'UP':
                    log("Wi-Fi Deactivated.")
                    subprocess.run(['nmcli', 'radio', 'wifi', 'off'])
            time.sleep(5)
    except KeyboardInterrupt:
        pass
    finally:
        pass

def handle_poweroff_button(stop_event):
    try:
        pressed_time = 0
        while not stop_event.is_set():
            if GPIO.input(poweroffPin) == GPIO.LOW:
                pressed_time += 0.1
                if pressed_time >= 10:
                    log("Shutdown detected.")
                    subprocess.call(["sudo", "shutdown", "-h", "now"])
                    break
            else:
                pressed_time = 0
            time.sleep(0.1)
    except KeyboardInterrupt:
        pass
    finally:
        pass

def led_indicator(stop_event):
    try:
        while not stop_event.is_set():
            mode = get_interface_mode('wlan0')
            state = get_interface_state('wlan0')
            if mode and state == 'UP':
                if mode == 'AP':
                    log("Wi-Fi Hotspot Enable.")
                    GPIO.output(ledPin, GPIO.HIGH)
                    time.sleep(0.5)
                    GPIO.output(ledPin, GPIO.LOW)
                    time.sleep(0.5)
                elif mode == 'managed':
                    log("Wi-Fi client.")
                    GPIO.output(ledPin, GPIO.HIGH)
                    time.sleep(1)
                else:
                    log("Wi-Fi not connected.")
                    GPIO.output(ledPin, GPIO.HIGH)
                    time.sleep(0.2)
                    GPIO.output(ledPin, GPIO.LOW)
                    time.sleep(0.2)
                    GPIO.output(ledPin, GPIO.HIGH)
                    time.sleep(0.2)
                    GPIO.output(ledPin, GPIO.LOW)
                    time.sleep(0.4)
            else:
                log("Wi-Fi OFF.")
                GPIO.output(ledPin, GPIO.LOW)
                time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        pass

def main():
    stop_event = multiprocessing.Event()

    def handle_sigterm(signum, frame):
        log("SIGTERM receive.")
        stop_event.set()

    signal.signal(signal.SIGTERM, handle_sigterm)

    try:
        p1 = multiprocessing.Process(target=handle_wifi_button, args=(stop_event,))
        p2 = multiprocessing.Process(target=handle_poweroff_button, args=(stop_event,))
        p3 = multiprocessing.Process(target=led_indicator, args=(stop_event,))

        p1.start()
        p2.start()
        p3.start()

        p1.join()
        p2.join()
        p3.join()

    except KeyboardInterrupt:
        log("Keyboard interruption.")
        stop_event.set()
    finally:
        p1.join()
        p2.join()
        p3.join()
        GPIO.cleanup()
        sys.exit(0)

if __name__ == "__main__":
    main()
