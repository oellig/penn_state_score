# ESPHome College Football Score Speaker

An ESPHome-based Wi-Fi speaker that monitors ESPN college football scores and plays a sound when the configured team's score increases by a configurable threshold.

Designed for an ESP32 with a MAX98357A I2S amplifier and speaker.

## Features

* ESPN college football score monitoring
* Detects score increases
* Configurable scoring threshold
* Plays an embedded MP3 when the threshold is reached
* Physical pushbutton for manual playback
* Web interface for configuration and controls
* OTA firmware updates
* Displays:

* Game Status
* Opponent
* Opponent Score
* Period
* Score Difference
* Scoring Event
* Scoring Team
* Team
* sTeam Score

## Hardware

### ESP32

Classic ESP32-WROOM / ESP32 DevKit.

### MAX98357A

| MAX98357A   | ESP32   |
| ----------- | ------- |
| BCLK        | GPIO26  |
| LRC / WS    | GPIO25  |
| DIN         | GPIO22  |
| VIN         | 5V      |
| GND         | GND     |
| OUT+ / OUT- | Speaker |

### Pushbutton

| Button     | ESP32  |
| ---------- | ------ |
| One side   | GPIO33 |
| Other side | GND    |

The button uses the ESP32 internal pull-up.

## Software

* ESPHome
* ESP32
* ESP-IDF framework
* ESPN API
* MAX98357A I2S amplifier

## Configuration

The main configuration is controlled through substitutions near the top of the YAML file.

Example:

```yaml
substitutions:
  device_name: "penn-state-score"
  friendly_name: "Penn State Score"

  i2s_bclk_pin: GPIO26
  i2s_lrc_pin: GPIO25
  i2s_dout_pin: GPIO22
  button_pin: GPIO33

  default_team: "PSU"
  default_song_duration: "60"
  default_score_threshold: "6"
  default_volume: "0.75"
```


## Audio

The scoring sound is stored in the project and compiled into the ESP32 firmware.

Current file:

```text
sounds/psu.mp3
```

The file is referenced by the ESPHome `media_player` configuration.

The scoring song duration is configurable from the web interface.

## Project Structure

A typical project layout is:

```text
penn-state-score/
├── penn-state-score.yaml
├── sounds/
│   └── psu.mp3
└── README.md
```

## Data Flows

Currently all defaults are used in the penn-state-score.yaml file to point to the /docs/score.json file for updates. The score.json file is updated via the psu-score-publish.sh Bash script running on a home server that pulls the data from ESPN. 
