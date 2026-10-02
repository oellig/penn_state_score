# ESPHome College Football Score Speaker

An ESPHome-based Wi-Fi speaker that monitors ESPN college football scores and plays a sound when the configured team's score increases by a configurable threshold.

Designed for an ESP32 with a MAX98357A I2S amplifier and speaker.

## Features

* ESPN college football score monitoring
* Configure a team using:

  * ESPN abbreviation, such as `PSU`
  * ESPN numeric team ID, such as `87` for Notre Dame or `2509` for Purdue
* Detects score increases
* Configurable scoring threshold
* Plays an embedded MP3 when the threshold is reached
* Physical pushbutton for manual playback
* Web interface for configuration and controls
* OTA firmware updates
* Displays:

  * Team score
  * Opponent
  * Opponent score
  * Game status
  * Game clock
  * ESPN event ID
  * Last score change
  * Previous score
  * Last ESPN poll status

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

### Team selection

The team can be specified using either an ESPN abbreviation:

```text
PSU
```

or an ESPN numeric team ID:

```text
87
```

Using the numeric ID avoids the ESPN team lookup request and is useful when an abbreviation is unavailable or ambiguous.

Examples:

```text
PSU     Penn State
87      Notre Dame
2509    Purdue
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

## ESPN Data Flow

For a numeric team ID, the device uses the ESPN Core API directly:

```text
Team ID
   │
   ▼
Today's team events
   │
   ▼
Event ID
   │
   ▼
Event information
   │
   ├── Team score
   ├── Opponent score
   └── Game status
```

For an abbreviation such as `PSU`, the device first performs an ESPN team lookup to obtain the numeric team ID.

## Score Detection

On startup, the current score becomes the baseline.

For example:

```text
Current score: 42
Baseline:      42
```

If the score later becomes:

```text
48
```

and the configured threshold is:

```text
6
```

the scoring sound is played.

The previous score and score change are also displayed in the web interface.

## Building

Compile using ESPHome:

```bash
esphome compile penn-state-score.yaml
```

Upload over USB:

```bash
esphome upload penn-state-score.yaml
```

After the first installation, OTA updates can be used.

## Web Interface

The ESPHome web interface provides controls and configuration for:

* Team
* Song duration
* Score threshold
* Speaker volume
* Current score
* Opponent
* Opponent score
* Game status
* Game clock
* ESPN event ID
* Last ESPN poll
* Previous score
* Last score change

It also provides controls for:

* Check ESPN Now
* Play Song
* Stop Song
* Reset Score Tracking
* Restart Device

## Troubleshooting

### Team lookup returns `IncompleteInput`

ESPN's team lookup response can be considerably larger than the ESP32 HTTP response buffer.

Using the numeric ESPN team ID avoids this lookup.

For example:

```text
87
```

instead of:

```text
Notre Dame
```

### ESPN HTTPS connection failures

The ESP32 makes several HTTPS requests while determining the current game and scores. Multiple TLS connections can put significant memory pressure on the ESP32.

If TLS errors such as:

```text
mbedtls_ssl_setup returned -0x7F00
```

appear, check the number and size of HTTPS requests being made and the ESP32's available memory.

### No scoring sound

Check:

1. The configured team ID.
2. The score threshold.
3. The embedded MP3 file.
4. MAX98357A wiring.
5. Speaker wiring.
6. Speaker volume.
7. The ESPHome logs for score-change messages.

## Notes

This project uses ESPN's publicly accessible web APIs. These APIs are not necessarily guaranteed to remain unchanged, so the ESPN request URLs and JSON parsing may need to be updated if ESPN changes its API.

The firmware is intended to be easily updated through ESPHome OTA when changes are required.
