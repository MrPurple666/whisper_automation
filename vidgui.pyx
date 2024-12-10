# vidgui.pyx
import tkinter as tk
from tkinter import filedialog, messagebox, ttk, simpledialog
import threading
from createvid import VideoProcessor
import whisper
import os
import cv2
from PIL import Image, ImageTk

cdef class VideoProcessingGUI:
    cdef object root
    cdef object url_entry
    cdef object start_time_entry
    cdef object end_time_entry
    cdef object progress_bar
    cdef object status_label
    cdef object preview_label
    cdef str current_video_path
    cdef object video_cap
    cdef object preview_thread

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Advanced Video Processing Tool")
        self.root.geometry("800x900")
        
        self.current_video_path = ""
        self.video_cap = None
        self.preview_thread = None
        
        self._create_widgets()
        self._setup_preview_area()
        
    def _create_widgets(self):
        # Main Frame
        main_frame = tk.Frame(self.root)
        main_frame.pack(padx=20, pady=20, fill=tk.BOTH, expand=True)
        
        # Left Column (Controls)
        left_frame = tk.Frame(main_frame)
        left_frame.pack(side=tk.LEFT, padx=10, fill=tk.Y)
        
        # Video Source Selection
        tk.Label(left_frame, text="Video Source:", font=("Helvetica", 12, "bold")).pack(pady=(10, 5))
        
        source_frame = tk.Frame(left_frame)
        source_frame.pack(pady=(0, 10))
        
        # YouTube URL Input
        url_subframe = tk.Frame(source_frame)
        url_subframe.pack(fill=tk.X)
        
        tk.Label(url_subframe, text="YouTube URL:").pack(side=tk.LEFT)
        self.url_entry = tk.Entry(url_subframe, width=30)
        self.url_entry.pack(side=tk.LEFT, padx=(5, 0))
        
        # Local File Selection Button
        tk.Button(source_frame, text="Select Local Video", command=self._select_local_video).pack(pady=5)
        
        # Separator
        ttk.Separator(left_frame, orient='horizontal').pack(fill=tk.X, pady=10)
        
        # Time Crop Section
        tk.Label(left_frame, text="Start Time (HH:MM:SS):").pack()
        self.start_time_entry = tk.Entry(left_frame, width=20)
        self.start_time_entry.pack()
        
        tk.Label(left_frame, text="End Time (HH:MM:SS):").pack()
        self.end_time_entry = tk.Entry(left_frame, width=20)
        self.end_time_entry.pack()
        
        # Buttons Section
        buttons_frame = tk.Frame(left_frame)
        buttons_frame.pack(pady=20)
        
        tk.Button(buttons_frame, text="Download Video", command=self._download_video).pack(side=tk.TOP, pady=5)
        tk.Button(buttons_frame, text="Cut Video", command=self._cut_video).pack(side=tk.TOP, pady=5)
        tk.Button(buttons_frame, text="Generate Subtitles", command=self._generate_subtitles).pack(side=tk.TOP, pady=5)
        tk.Button(buttons_frame, text="Add Subtitles", command=self._add_subtitles).pack(side=tk.TOP, pady=5)
        
        # Progress and Status
        self.progress_bar = ttk.Progressbar(left_frame, orient='horizontal', length=300, mode='determinate')
        self.progress_bar.pack(pady=10)
        
        self.status_label = tk.Label(left_frame, text="Ready", fg="green")
        self.status_label.pack(pady=10)
        
    def _select_local_video(self):
        """Open file dialog to select a local video file"""
        filetypes = [
            ('Video Files', '*.mp4 *.avi *.mov *.mkv'), 
            ('All Files', '*.*')
        ]
        
        # Open file dialog
        selected_file = filedialog.askopenfilename(
            title="Select a Video File",
            filetypes=filetypes
        )
        
        # If a file was selected
        if selected_file:
            try:
                # Clear YouTube URL if a local file is selected
                self.url_entry.delete(0, tk.END)
                
                # Set current video path
                self.current_video_path = selected_file
                
                # Update status
                self._update_status(f"Local video selected: {os.path.basename(selected_file)}")
                
                # Optional: Automatically start preview
                self._start_video_preview("00:00:00")
            except Exception as e:
                self._update_status(f"Error selecting video: {str(e)}", 'red')
                messagebox.showerror("File Selection Error", str(e))
        
    def _setup_preview_area(self):
        # Right Column (Video Preview)
        preview_frame = tk.Frame(self.root)
        preview_frame.pack(side=tk.RIGHT, padx=20, pady=20)
        
        tk.Label(preview_frame, text="Video Preview", font=("Helvetica", 12, "bold")).pack()
        
        self.preview_label = tk.Label(preview_frame)
        self.preview_label.pack(pady=10)
        
        preview_controls_frame = tk.Frame(preview_frame)
        preview_controls_frame.pack()
        
        tk.Button(preview_controls_frame, text="Select Timestamp", command=self._select_preview_timestamp).pack(side=tk.LEFT, padx=5)
        tk.Button(preview_controls_frame, text="Stop Preview", command=self._stop_preview).pack(side=tk.LEFT, padx=5)
    
    def _select_preview_timestamp(self):
        if not self.current_video_path:
            messagebox.showwarning("Warning", "Please select a video first.")
            return
        
        timestamp = simpledialog.askstring("Preview", "Enter timestamp (HH:MM:SS):")
        if timestamp:
            self._start_video_preview(timestamp)
    
    def _start_video_preview(self, timestamp):
        # Stop any existing preview
        self._stop_preview()
        
        try:
            # Convert timestamp to seconds
            hours, minutes, seconds = map(int, timestamp.split(':'))
            total_seconds = hours * 3600 + minutes * 60 + seconds
            
            # Open video capture
            self.video_cap = cv2.VideoCapture(self.current_video_path)
            self.video_cap.set(cv2.CAP_PROP_POS_MSEC, total_seconds * 1000)
            
            # Start preview thread
            self.preview_thread = threading.Thread(target=self._update_preview, daemon=True)
            self.preview_thread.start()
        except Exception as e:
            messagebox.showerror("Preview Error", str(e))
    
    def _update_preview(self):
        while self.video_cap and self.video_cap.isOpened():
            ret, frame = self.video_cap.read()
            if not ret:
                break
            
            # Resize frame to fit preview
            frame = cv2.resize(frame, (400, 600))
            
            # Convert frame to PhotoImage
            cv2_img = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            pil_img = Image.fromarray(cv2_img)
            photo = ImageTk.PhotoImage(image=pil_img)
            
            # Update preview in main thread
            self.root.after(0, self._display_preview, photo)
            
            # Control frame rate
            import time
            time.sleep(0.1)
    
    def _display_preview(self, photo):
        self.preview_label.configure(image=photo)
        self.preview_label.image = photo  # Keep a reference
    
    def _stop_preview(self):
        if self.video_cap:
            self.video_cap.release()
            self.video_cap = None
        self.preview_label.configure(image='')
    
    def _update_status(self, message, color='green'):
        self.status_label.config(text=message, fg=color)
        self.root.update_idletasks()
    
    def _download_video(self):
        url = self.url_entry.get()
        if not url:
            messagebox.showwarning("Warning", "Please enter a YouTube URL")
            return
        
        threading.Thread(target=self._threaded_download, args=(url,)).start()
    
    def _threaded_download(self, url):
        try:
            self._update_status("Downloading video...", 'blue')
            video_path = VideoProcessor.download_video(url)
            self.current_video_path = video_path
            self._update_status(f"Video downloaded: {video_path}")
            
            # Automatically start preview from the beginning
            self._start_video_preview("00:00:00")
        except Exception as e:
            self._update_status(f"Download Error: {str(e)}", 'red')
            messagebox.showerror("Download Error", str(e))
    
    def _cut_video(self):
        if not self.current_video_path:
            messagebox.showwarning("Warning", "Please select or download a video first")
            return
        
        start_time = self.start_time_entry.get()
        end_time = self.end_time_entry.get()
        threading.Thread(target=self._threaded_cut, args=(start_time, end_time)).start()
    
    def _threaded_cut(self, start_time, end_time):
        try:
            self._update_status("Cutting video...", 'blue')
            video_path = VideoProcessor.cut_video(self.current_video_path, start_time, end_time)
            self.current_video_path = video_path
            self._update_status(f"Video cut: {video_path}")
            
            # Automatically start preview from the beginning of cut video
            self._start_video_preview("00:00:00")
        except Exception as e:
            self._update_status(f"Cut Error: {str(e)}", 'red')
            messagebox.showerror("Cut Error", str(e))
    
    def _generate_subtitles(self):
        if not self.current_video_path:
            messagebox.showwarning("Warning", "Please select or download a video first")
            return
        
        threading.Thread(target=self._threaded_subtitles).start()
    
    def _threaded_subtitles(self):
        try:
            self._update_status("Generating subtitles...", 'blue')
            subtitles = VideoProcessor.generate_subtitles(self.current_video_path)
            self._update_status(f"Subtitles generated: {subtitles}")
        except Exception as e:
            self._update_status(f"Subtitle Error: {str(e)}", 'red')
            messagebox.showerror("Subtitle Error", str(e))
    
    def _add_subtitles(self):
        if not self.current_video_path:
            messagebox.showwarning("Warning", "Please select or download a video first")
            return
        
        threading.Thread(target=self._threaded_add_subtitles).start()
    
    def _threaded_add_subtitles(self):
        try:
            self._update_status("Adding subtitles...", 'blue')
            final_video = VideoProcessor.add_subtitles(self.current_video_path, "subtitles.srt")
            self._update_status(f"Final video created: {final_video}")
        except Exception as e:
            self._update_status(f"Subtitle Add Error: {str(e)}", 'red')
            messagebox.showerror("Subtitle Add Error", str(e))
    
    def run(self):
        self.root.mainloop()

def launch_gui():
    whisper.load_model("medium")  # Pre-load Whisper model
    app = VideoProcessingGUI()
    app.run()