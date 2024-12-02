from createvid import VideoProcessor
import whisper

whisper.load_model("medium")  # or "small", "base", etc.

# Interactively download and process a video
def interactive_video_processing():
    # Get video URL
    video_url = input("Enter YouTube video URL: ")
    
    # Download video
    downloaded_video = VideoProcessor.download_video(video_url)
    print(f"Video downloaded: {downloaded_video}")
    
    # Get cutting times
    start_time = input("Enter start time (HH:MM:SS): ")
    end_time = input("Enter end time (HH:MM:SS): ")
    
    # Cut video
    cut_video = VideoProcessor.cut_video(downloaded_video, start_time, end_time)
    print(f"Video cut: {cut_video}")
    
    # Generate subtitles
    subtitles = VideoProcessor.generate_subtitles(cut_video)
    print(f"Subtitles generated: {subtitles}")
    
    # Add subtitles to video
    final_video = VideoProcessor.add_subtitles(cut_video, subtitles)
    print(f"Final video created: {final_video}")

# Run the interactive processing
interactive_video_processing()