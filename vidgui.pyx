# vidgui.pyx
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import threading
from createvid import VideoProcessor
import whisper
import os

cdef class VideoProcessingGUI:
    cdef object root
    cdef object url_entry
    cdef object start_time_entry
    cdef object end_time_entry
    cdef object progress_bar
    cdef object status_label

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Advanced Video Processing Tool")
        self.root.geometry("600x700")
        
        self._create_widgets()
        
    def _create_widgets(self):
        # URL Input Section
        tk.Label(self.root, text="YouTube Video URL:").pack(pady=(10, 0))
        self.url_entry = tk.Entry(self.root, width=50)
        self.url_entry.pack(pady=(0, 10))
        
        # Time Crop Section
        tk.Label(self.root, text="Start Time (HH:MM:SS):").pack()
        self.start_time_entry = tk.Entry(self.root, width=20)
        self.start_time_entry.pack()
        
        tk.Label(self.root, text="End Time (HH:MM:SS):").pack()
        self.end_time_entry = tk.Entry(self.root, width=20)
        self.end_time_entry.pack()
        
        # Buttons Section
        tk.Button(self.root, text="Download Video", command=self._download_video).pack(pady=10)
        tk.Button(self.root, text="Cut Video", command=self._cut_video).pack(pady=10)
        tk.Button(self.root, text="Generate Subtitles", command=self._generate_subtitles).pack(pady=10)
        tk.Button(self.root, text="Add Subtitles", command=self._add_subtitles).pack(pady=10)
        
        # Advanced Video Processing
        tk.Button(self.root, text="Crop Video", command=self._crop_video).pack(pady=10)
        tk.Button(self.root, text="Resize Video", command=self._resize_video).pack(pady=10)
        
        # Progress and Status
        self.progress_bar = ttk.Progressbar(self.root, orient='horizontal', length=500, mode='determinate')
        self.progress_bar.pack(pady=10)
        
        self.status_label = tk.Label(self.root, text="Ready", fg="green")
        self.status_label.pack(pady=10)
        
    def _update_status(self, message):
        self.status_label.config(text=message)
        self.root.update_idletasks()
    
    def _download_video(self):
        url = self.url_entry.get()
        threading.Thread(target=self._threaded_download, args=(url,)).start()
    
    def _threaded_download(self, url):
        try:
            video_path = VideoProcessor.download_video(url)
            self._update_status(f"Video downloaded: {video_path}")
        except Exception as e:
            messagebox.showerror("Download Error", str(e))
    
    def _cut_video(self):
        start_time = self.start_time_entry.get()
        end_time = self.end_time_entry.get()
        threading.Thread(target=self._threaded_cut, args=(start_time, end_time)).start()
    
    def _threaded_cut(self, start_time, end_time):
        try:
            video_path = VideoProcessor.cut_video(start_time, end_time)
            self._update_status(f"Video cut: {video_path}")
        except Exception as e:
            messagebox.showerror("Cut Error", str(e))
    
    def _generate_subtitles(self):
        threading.Thread(target=self._threaded_subtitles).start()
    
    def _threaded_subtitles(self):
        try:
            subtitles = VideoProcessor.generate_subtitles()
            self._update_status(f"Subtitles generated: {subtitles}")
        except Exception as e:
            messagebox.showerror("Subtitle Error", str(e))
    
    def _add_subtitles(self):
        threading.Thread(target=self._threaded_add_subtitles).start()
    
    def _threaded_add_subtitles(self):
        try:
            final_video = VideoProcessor.add_subtitles()
            self._update_status(f"Final video created: {final_video}")
        except Exception as e:
            messagebox.showerror("Subtitle Add Error", str(e))
    
    def run(self):
        self.root.mainloop()

def launch_gui():
    app = VideoProcessingGUI()
    app.run()