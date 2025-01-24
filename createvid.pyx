import os
import subprocess
from libc.stdio cimport FILE, fopen, fclose, fprintf
from libc.stdlib cimport malloc, free
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from yt_dlp import YoutubeDL
import whisper
import ffmpeg

# Cython optimized functions
cdef class VideoProcessor:
    cpdef str download_video(self, str video_url, str output_path="video.mp4"):
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

    cpdef str cut_video(self, str input_path, str start_time, str end_time, str output_path="output.mp4"):
        """Cut video using python-ffmpeg for vertical format."""
        cdef bytes input_bytes = input_path.encode('utf-8')
        cdef bytes start_bytes = start_time.encode('utf-8')
        cdef bytes end_bytes = end_time.encode('utf-8')
        cdef bytes output_bytes = output_path.encode('utf-8')
        return self._cut_video_c(input_bytes, start_bytes, end_bytes, output_bytes)

    cdef str _cut_video_c(self, const char* input_path, const char* start_time, const char* end_time, const char* output_path) except *:
        """Internal C function for cutting video using python-ffmpeg."""
        cdef str input_path_str = input_path.decode('utf-8')
        cdef str start_time_str = start_time.decode('utf-8')
        cdef str end_time_str = end_time.decode('utf-8')
        cdef str output_path_str = output_path.decode('utf-8')

        try:
            (
                ffmpeg
                .input(input_path_str, ss=start_time_str, to=end_time_str)
                .filter('scale', 1080, 1920)
                .filter('setsar', '1:1')
                .output(output_path_str, vcodec='libx264', preset='fast', crf=23, acodec='aac', strict='experimental')
                .run(quiet=True)
            )
        except ffmpeg.Error as e:
            raise RuntimeError(f"FFmpeg failed to cut the video: {e.stderr.decode('utf-8')}")

        return output_path_str

    cpdef str generate_subtitles(self, str input_path, str model="medium"):
        """Generate subtitles using Whisper."""
        cdef object whisper_model = whisper.load_model(model)
        cdef dict result = whisper_model.transcribe(input_path)
        cdef str subtitles_path = "subtitles.srt"
        self.whisper_to_srt(result, subtitles_path)
        return subtitles_path

    cpdef void whisper_to_srt(self, dict whisper_result, str subtitles_path):
        """Convert Whisper transcription to SRT format."""
        cdef bytes path_bytes = subtitles_path.encode('utf-8')
        cdef const char* c_path = path_bytes
        self._whisper_to_srt_c(whisper_result, c_path)

    cdef void _whisper_to_srt_c(self, dict whisper_result, const char* subtitles_path) nogil:
        """Internal C function for writing SRT."""
        cdef FILE* file
        cdef int i, hours, minutes, secs, millis
        cdef int end_hours, end_minutes, end_secs, end_millis
        cdef double start, end
        cdef const char* text

        file = fopen(subtitles_path, "w")
        if not file:
            with gil:
                raise IOError("Could not open subtitles file.")

        try:
            for i, segment in enumerate(whisper_result["segments"]):
                start = segment["start"]
                end = segment["end"]
                text = segment["text"].strip().encode('utf-8')

                # Convert times
                hours = <int>(start // 3600)
                minutes = <int>((start % 3600) // 60)
                secs = <int>(start % 60)
                millis = <int>((start - <int>start) * 1000)

                end_hours = <int>(end // 3600)
                end_minutes = <int>((end % 3600) // 60)
                end_secs = <int>(end % 60)
                end_millis = <int>((end - <int>end) * 1000)

                # Write to file
                fprintf(file, b"%d\n", i + 1)
                fprintf(file, b"%02d:%02d:%02d,%03d --> %02d:%02d:%02d,%03d\n",
                        hours, minutes, secs, millis,
                        end_hours, end_minutes, end_secs, end_millis)
                fprintf(file, b"%s\n\n", text)
        finally:
            fclose(file)

    cpdef str add_subtitles(self, str video_path, str subtitles_path, str output_path="final_output.mp4"):
        """Add subtitles to video using python-ffmpeg."""
        if not os.path.exists(subtitles_path):
            raise FileNotFoundError("Subtitles file 'subtitles.srt' not found.")
        cdef str abs_subtitles_path = os.path.abspath(subtitles_path)

        try:
            (
                ffmpeg
                .input(video_path)
                .output(output_path, vf=f"subtitles='{abs_subtitles_path}'", vcodec='libx264', crf=23, preset='fast', acodec='aac')
                .run(quiet=True)
            )
        except ffmpeg.Error as e:
            raise RuntimeError(f"FFmpeg failed to add subtitles to the video: {e.stderr.decode('utf-8')}")

        return output_path

def main():
    # Prompt for video link
    video_url = input("Enter the YouTube video URL: ")
    output_path = VideoProcessor().download_video(video_url)
    print(f"Video downloaded to: {output_path}")

    # Prompt for cutting times
    start_time = input("Enter start time (HH:MM:SS): ")
    end_time = input("Enter end time (HH:MM:SS): ")
    cut_output_path = VideoProcessor().cut_video(output_path, start_time, end_time)
    print(f"Video cut and saved to: {cut_output_path}")

    # Generate subtitles
    subtitles_path = VideoProcessor().generate_subtitles(cut_output_path)
    print(f"Subtitles saved to: {subtitles_path}")

    # Add subtitles to the video
    final_output_path = VideoProcessor().add_subtitles(cut_output_path, subtitles_path)
    print(f"Final video with subtitles saved to: {final_output_path}")

if __name__ == "__main__":
    main()