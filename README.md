# whisper_automation

A Python-based automation tool that creates short videos from full-length YouTube videos using ffmpeg and OpenAI's Whisper speech recognition model.

## Features

- Download YouTube videos
- Cut videos to specified time ranges
- Generate subtitles using OpenAI's Whisper model
- Add subtitles to videos
- User-friendly GUI interface

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/MrPurple666/whisper_automation.git
   cd whisper_automation
   ```

2. Install the required dependencies:
   ```
   pip install -r requirements.txt
   ```

3. Install ffmpeg:
   - On macOS (using Homebrew):
     ```
     brew install ffmpeg
     ```
   - On Ubuntu or Debian:
     ```
     sudo apt-get update
     sudo apt-get install ffmpeg
     ```
   - On Windows, download from the [official ffmpeg website](https://ffmpeg.org/download.html) and add it to your system PATH.

   - On Arch Linux (using AUR):
     ```
     yay -S ffmpeg
     ```
     If you don't have yay installed, you can install it first:
     ```
     sudo pacman -S --needed git base-devel
     git clone https://aur.archlinux.org/yay.git
     cd yay
     makepkg -si
     ```

   - On Fedora:
     ```
     sudo dnf install ffmpeg
     ```

## Usage

### Build

Build the program with this:

```
python setup.py build_ext --inplace
```

### GUI Interface

To launch the graphical user interface:

```
python launch_gui.py
```

Follow the on-screen instructions to process your videos.

### Command-line Interface

For command-line usage:

```
python run.py
```

You will be prompted to:
1. Enter a YouTube video URL
2. Specify the start and end times for cutting the video
3. The script will then download the video, cut it, generate subtitles, and add them to the final video.

## File Structure

- `launch_gui.py`: Entry point for the GUI application
- `run.py`: Command-line interface for video processing
- `setup.py`: Build script for compiling Cython extensions
- `createvid.pyx`: Cython source for video processing functions
- `vidgui.pyx`: Cython source for GUI components

## Note

This project uses OpenAI's Whisper model for speech recognition. Ensure you have the necessary permissions and comply with OpenAI's usage terms when using this tool.