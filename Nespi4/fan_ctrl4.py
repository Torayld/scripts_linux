#!/usr/bin/python3

import RPi.GPIO as GPIO
import time
import signal
import sys
import threading
from collections import deque
from datetime import datetime

# --- GPIO Pins ---
FAN_PIN = 18

# --- Setup GPIO ---
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(FAN_PIN, GPIO.OUT, initial=GPIO.LOW)

# --- Configuration ---
PWM_FREQ = 25           # [Hz]
WAIT_TIME = 1           # [s]
FAN_RUN_TIME = 60       # [s]
OFF_TEMP = 40           # [°C]
MIN_TEMP = 45           # [°C]
MAX_TEMP = 70           # [°C]
FAN_LOW = 1
FAN_HIGH = 100
FAN_OFF = 0
FAN_GAIN = float(FAN_HIGH - FAN_LOW) / float(MAX_TEMP - MIN_TEMP)
SMOOTHING_FACTOR = 0.1
TEMP_HISTORY_SIZE = 5

# --- État ---
fan_running = False
fan_start_time = None
current_speed = FAN_OFF

# --- Utilitaires ---
def log(message):
    if sys.stdout.isatty():
        now = datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
        print(f"{now} {message}")

def getCpuTemperature():
    with open('/sys/class/thermal/thermal_zone0/temp') as f:
        return float(f.read()) / 1000

def setFanSpeed(pwm, target_speed):
    global current_speed
    current_speed = current_speed + SMOOTHING_FACTOR * (target_speed - current_speed)
    pwm.ChangeDutyCycle(current_speed)
    log(f"Speed Fan adjust : {current_speed:.1f}% (target : {target_speed:.1f}%)")

def fanControlThread(stop_event):
    global fan_running, fan_start_time
    fan = GPIO.PWM(FAN_PIN, PWM_FREQ)
    fan.start(FAN_OFF)

    temp_history = deque(maxlen=TEMP_HISTORY_SIZE)

    try:
        while not stop_event.is_set():
            temp = getCpuTemperature()
            temp_history.append(temp)
            avg_temp = sum(temp_history) / len(temp_history)

            log(f"CPU Temp : {temp:.2f} °C (average : {avg_temp:.2f} °C)")

            if avg_temp > MIN_TEMP:
                delta = min(avg_temp, MAX_TEMP) - MIN_TEMP
                target_speed = FAN_LOW + delta * FAN_GAIN

                if not fan_running:
                    fan_running = True
                    fan_start_time = time.time()

                try:
                    setFanSpeed(fan, target_speed)
                except RuntimeError as e:
                    log(f"Error PWM : {e}")

            elif avg_temp < OFF_TEMP:
                if fan_running and (time.time() - fan_start_time < FAN_RUN_TIME):
                    pass
                else:
                    try:
                        setFanSpeed(fan, FAN_OFF)
                    except RuntimeError as e:
                        log(f"Error PWM : {e}")
                    fan_running = False

            time.sleep(WAIT_TIME)

    except KeyboardInterrupt:
        log("Keyboard interruption.")
    finally:
        try:
            fan.stop()
        except Exception as e:
            log(f"Error stopping fan : {e}")


def main():
    stop_event = threading.Event()

    def handle_sigterm(signum, frame):
        stop_event.set()

    signal.signal(signal.SIGTERM, handle_sigterm)
    signal.signal(signal.SIGINT, handle_sigterm)

    fan_thread = threading.Thread(target=fanControlThread, args=(stop_event,))
    fan_thread.start()

    fan_thread.join()
    GPIO.cleanup()
    sys.exit(0)

if __name__ == "__main__":
    main()
