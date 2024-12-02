import os
import subprocess
from libc.stdio cimport FILE, fopen, fclose, fprintf
from libc.stdlib cimport malloc, free
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from yt_dlp import YoutubeDL
import whisper

# Cython optimized functions
cdef class VideoProcessor:
    @staticmethod
    def download_video(str video_url, str output_path="video.mp4"):
        """Download video from YouTube using yt-dlp."""
        cdef dict ydl_opts = {
            'format': 'mp4',
            'outtmpl': output_path,
            'no_warnings': True,
            'quiet': True
        }
        with YoutubeDL(ydl_opts) as ydl:
            ydl.download([video_url])
        return output_path

    @staticmethod
    def cut_video(str input_path, str start_time, str end_time, str output_path="output.mp4"):
        """Cut video using FFmpeg for vertical format."""
        cdef list command = [
            "ffmpeg",
            "-i", input_path,
            "-ss", start_time,
            "-to", end_time,
            "-vf", "scale=1080:1920,setsar=1:1",
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "23",
            "-c:a", "aac",
            "-strict", "experimental",
            output_path
        ]
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            raise RuntimeError("FFmpeg failed to cut the video.")
        return output_path

    @staticmethod
    def generate_subtitles(str input_path, str model="medium"):
        """Generate subtitles using Whisper."""
        print("Loading Whisper model...")
        whisper_model = whisper.load_model(model)
        print("Transcribing audio from video...")
        result = whisper_model.transcribe(input_path)

        # Generate SRT
        subtitles_path = "subtitles.srt"
        VideoProcessor.whisper_to_srt(result, subtitles_path)
        print("Subtitles generated successfully.")
        return subtitles_path

    @staticmethod
    def whisper_to_srt(dict whisper_result, str subtitles_path):
        """Convert Whisper transcription to SRT format."""
        cdef FILE* file
        cdef int i, hours, minutes, secs, millis
        cdef int end_hours, end_minutes, end_secs, end_millis
        cdef double start, end
        cdef bytes text_bytes
        
        file = fopen(subtitles_path.encode('utf-8'), "w")
        if not file:
            raise IOError("Could not open subtitles file.")

        try:
            for i, segment in enumerate(whisper_result["segments"]):
                start = segment["start"]
                end = segment["end"]
                text_bytes = segment["text"].strip().encode('utf-8')

                # Start time conversion
                hours = int(start // 3600)
                minutes = int((start % 3600) // 60)
                secs = int(start % 60)
                millis = int((start - int(start)) * 1000)

                # End time conversion
                end_hours = int(end // 3600)
                end_minutes = int((end % 3600) // 60)
                end_secs = int(end % 60)
                end_millis = int((end - int(end)) * 1000)

                # Writing subtitles
                fprintf(file, b"%d\n", i + 1)
                fprintf(file, b"%02d:%02d:%02d,%03d --> %02d:%02d:%02d,%03d\n",
                        hours, minutes, secs, millis,
                        end_hours, end_minutes, end_secs, end_millis)
                fprintf(file, b"%s\n\n", text_bytes)
        finally:
            fclose(file)

    @staticmethod
    def add_subtitles(str video_path, str subtitles_path, str output_path="final_output.mp4"):
        """Add subtitles to video using FFmpeg."""
        if not os.path.exists(subtitles_path):
            raise FileNotFoundError("Subtitles file 'subtitles.srt' not found.")

        # Absolute path for subtitles
        abs_subtitles_path = os.path.abspath(subtitles_path)
        
        command = [
                "ffmpeg",
                "-i", video_path,
                "-vf", f"subtitles='{abs_subtitles_path}'",
                "-c:v", "libx264",
                "-crf", "23",
                "-preset", "fast",
                "-c:a", "aac",
                output_path
            ]
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            raise RuntimeError("FFmpeg failed to add subtitles to the video.")
        return output_path

def main():
    # Prompt for video link
    video_url = input("Enter the YouTube video URL: ")
    output_path = VideoProcessor.download_video(video_url)
    print(f"Video downloaded to: {output_path}")

    # Prompt for cutting times
    start_time = input("Enter start time (HH:MM:SS): ")
    end_time = input("Enter end time (HH:MM:SS): ")
    cut_output_path = VideoProcessor.cut_video(output_path, start_time, end_time)
    print(f"Video cut and saved to: {cut_output_path}")

    # Generate subtitles
    subtitles_path = VideoProcessor.generate_subtitles(cut_output_path)
    print(f"Subtitles saved to: {subtitles_path}")

    # Add subtitles to the video
    final_output_path = VideoProcessor.add_subtitles(cut_output_path, subtitles_path)
    print(f"Final video with subtitles saved to: {final_output_path}")

if __name__ == "__main__":
    main()