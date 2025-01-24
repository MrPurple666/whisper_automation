# vidgui.pyx
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton,
    QProgressBar, QFileDialog, QMessageBox, QFrame, QInputDialog
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QTimer
from PyQt5.QtGui import QImage, QPixmap
from createvid import VideoProcessor
import whisper
import os
import cv2
import numpy as np

class VideoProcessingGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.video_processor = VideoProcessor()
        self.current_video_path = ""
        self.video_cap = None
        self.preview_timer = QTimer()
        self.preview_timer.timeout.connect(self._update_preview)
        self._init_ui()

    def _init_ui(self):
        self.setWindowTitle("Advanced Video Processing Tool")
        self.setGeometry(100, 100, 1200, 800)

        # Main layout
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        main_layout = QHBoxLayout(main_widget)

        # Left panel (controls)
        left_panel = QFrame()
        left_panel.setFrameShape(QFrame.StyledPanel)
        left_panel.setFixedWidth(400)
        left_layout = QVBoxLayout(left_panel)

        # Video source selection
        source_label = QLabel("Video Source:")
        source_label.setStyleSheet("font-weight: bold; font-size: 14px;")
        left_layout.addWidget(source_label)

        # YouTube URL input
        url_layout = QHBoxLayout()
        url_label = QLabel("YouTube URL:")
        self.url_entry = QLineEdit()
        url_layout.addWidget(url_label)
        url_layout.addWidget(self.url_entry)
        left_layout.addLayout(url_layout)

        # Local file selection button
        local_file_button = QPushButton("Select Local Video")
        local_file_button.clicked.connect(self._select_local_video)
        left_layout.addWidget(local_file_button)

        # Separator
        separator = QFrame()
        separator.setFrameShape(QFrame.HLine)
        separator.setFrameShadow(QFrame.Sunken)
        left_layout.addWidget(separator)

        # Time crop section
        time_label = QLabel("Time Crop:")
        time_label.setStyleSheet("font-weight: bold; font-size: 14px;")
        left_layout.addWidget(time_label)

        start_time_label = QLabel("Start Time (HH:MM:SS):")
        self.start_time_entry = QLineEdit()
        left_layout.addWidget(start_time_label)
        left_layout.addWidget(self.start_time_entry)

        end_time_label = QLabel("End Time (HH:MM:SS):")
        self.end_time_entry = QLineEdit()
        left_layout.addWidget(end_time_label)
        left_layout.addWidget(self.end_time_entry)

        # Buttons
        download_button = QPushButton("Download Video")
        download_button.clicked.connect(self.download_video)  # Corrected method name
        left_layout.addWidget(download_button)

        cut_button = QPushButton("Cut Video")
        cut_button.clicked.connect(self._cut_video)
        left_layout.addWidget(cut_button)

        subtitles_button = QPushButton("Generate Subtitles")
        subtitles_button.clicked.connect(self._generate_subtitles)
        left_layout.addWidget(subtitles_button)

        add_subtitles_button = QPushButton("Add Subtitles")
        add_subtitles_button.clicked.connect(self._add_subtitles)
        left_layout.addWidget(add_subtitles_button)

        # Progress bar
        self.progress_bar = QProgressBar()
        left_layout.addWidget(self.progress_bar)

        # Status label
        self.status_label = QLabel("Ready")
        self.status_label.setStyleSheet("color: green; font-size: 12px;")
        left_layout.addWidget(self.status_label)

        # Add left panel to main layout
        main_layout.addWidget(left_panel)

        # Right panel (video preview)
        right_panel = QFrame()
        right_panel.setFrameShape(QFrame.StyledPanel)
        right_layout = QVBoxLayout(right_panel)

        preview_label = QLabel("Video Preview")
        preview_label.setStyleSheet("font-weight: bold; font-size: 14px;")
        right_layout.addWidget(preview_label)

        self.preview_label = QLabel()
        self.preview_label.setAlignment(Qt.AlignCenter)
        right_layout.addWidget(self.preview_label)

        # Preview controls
        preview_controls_layout = QHBoxLayout()
        select_timestamp_button = QPushButton("Select Timestamp")
        select_timestamp_button.clicked.connect(self._select_preview_timestamp)
        preview_controls_layout.addWidget(select_timestamp_button)

        stop_preview_button = QPushButton("Stop Preview")
        stop_preview_button.clicked.connect(self._stop_preview)
        preview_controls_layout.addWidget(stop_preview_button)

        right_layout.addLayout(preview_controls_layout)

        # Add right panel to main layout
        main_layout.addWidget(right_panel)

    def _select_local_video(self):
        """Open file dialog to select a local video file."""
        filetypes = "Video Files (*.mp4 *.avi *.mov *.mkv);;All Files (*.*)"
        selected_file, _ = QFileDialog.getOpenFileName(self, "Select a Video File", "", filetypes)

        if selected_file:
            try:
                self.url_entry.clear()
                self.current_video_path = selected_file
                self._update_status(f"Local video selected: {os.path.basename(selected_file)}")
                self._start_video_preview("00:00:00")
            except Exception as e:
                self._update_status(f"Error selecting video: {str(e)}", 'red')
                QMessageBox.critical(self, "File Selection Error", str(e))

    def _start_video_preview(self, timestamp):
        """Start video preview from the given timestamp."""
        self._stop_preview()

        try:
            hours, minutes, seconds = map(int, timestamp.split(':'))
            total_seconds = hours * 3600 + minutes * 60 + seconds

            self.video_cap = cv2.VideoCapture(self.current_video_path)
            self.video_cap.set(cv2.CAP_PROP_POS_MSEC, total_seconds * 1000)

            self.preview_timer.start(100)  # Update every 100ms
        except Exception as e:
            QMessageBox.critical(self, "Preview Error", str(e))

    def _update_preview(self):
        """Update the video preview frame."""
        if self.video_cap and self.video_cap.isOpened():
            ret, frame = self.video_cap.read()
            if ret:
                frame = cv2.resize(frame, (600, 400))
                frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                h, w, ch = frame.shape
                bytes_per_line = ch * w
                q_img = QImage(frame.data, w, h, bytes_per_line, QImage.Format_RGB888)
                self.preview_label.setPixmap(QPixmap.fromImage(q_img))

    def _stop_preview(self):
        """Stop the video preview."""
        if self.video_cap:
            self.video_cap.release()
            self.video_cap = None
        self.preview_timer.stop()
        self.preview_label.clear()

    def _select_preview_timestamp(self):
        """Open a dialog to select a timestamp for the video preview."""
        timestamp, ok = QInputDialog.getText(self, "Select Timestamp", "Enter timestamp (HH:MM:SS):")
        if ok and timestamp:
            try:
                self._start_video_preview(timestamp)
            except Exception as e:
                QMessageBox.critical(self, "Timestamp Error", str(e))

    def _update_status(self, message, color='green'):
        """Update the status label."""
        self.status_label.setText(message)
        self.status_label.setStyleSheet(f"color: {color}; font-size: 12px;")

    def download_video(self, checked=False):
        """Download video from YouTube."""
        url = self.url_entry.text()
        if not url:
            QMessageBox.warning(self, "Warning", "Please enter a YouTube URL")
            return

        self._start_thread(self._threaded_download, url)

    def _threaded_download(self, url):
        """Threaded function to download video."""
        try:
            self._update_status("Downloading video...", 'blue')
            video_path = self.video_processor.download_video(url)
            self.current_video_path = video_path
            self._update_status(f"Video downloaded: {video_path}")
            self._start_video_preview("00:00:00")
        except Exception as e:
            self._update_status(f"Download Error: {str(e)}", 'red')
            QMessageBox.critical(self, "Download Error", str(e))

    def _cut_video(self, checked=False):
        """Cut video based on start and end times."""
        if not self.current_video_path:
            QMessageBox.warning(self, "Warning", "Please select or download a video first")
            return

        start_time = self.start_time_entry.text()
        end_time = self.end_time_entry.text()
        self._start_thread(self._threaded_cut, start_time, end_time)

    def _threaded_cut(self, start_time, end_time):
        """Threaded function to cut video."""
        try:
            self._update_status("Cutting video...", 'blue')
            video_path = self.video_processor.cut_video(self.current_video_path, start_time, end_time)
            self.current_video_path = video_path
            self._update_status(f"Video cut: {video_path}")
            self._start_video_preview("00:00:00")
        except Exception as e:
            self._update_status(f"Cut Error: {str(e)}", 'red')
            QMessageBox.critical(self, "Cut Error", str(e))

    def _generate_subtitles(self, checked=False):
        """Generate subtitles for the video."""
        if not self.current_video_path:
            QMessageBox.warning(self, "Warning", "Please select or download a video first")
            return

        self._start_thread(self._threaded_subtitles)

    def _threaded_subtitles(self):
        """Threaded function to generate subtitles."""
        try:
            self._update_status("Generating subtitles...", 'blue')
            subtitles = self.video_processor.generate_subtitles(self.current_video_path)
            self._update_status(f"Subtitles generated: {subtitles}")
        except Exception as e:
            self._update_status(f"Subtitle Error: {str(e)}", 'red')
            QMessageBox.critical(self, "Subtitle Error", str(e))

    def _add_subtitles(self, checked=False):
        """Add subtitles to the video."""
        if not self.current_video_path:
            QMessageBox.warning(self, "Warning", "Please select or download a video first")
            return

        self._start_thread(self._threaded_add_subtitles)

    def _threaded_add_subtitles(self):
        """Threaded function to add subtitles."""
        try:
            self._update_status("Adding subtitles...", 'blue')
            final_video = self.video_processor.add_subtitles(self.current_video_path, "subtitles.srt")
            self._update_status(f"Final video created: {final_video}")
        except Exception as e:
            self._update_status(f"Subtitle Add Error: {str(e)}", 'red')
            QMessageBox.critical(self, "Subtitle Add Error", str(e))

    def _start_thread(self, target, *args):
        """Start a new thread for a task."""
        thread = QThread(target=target, args=args)
        thread.start()

    def run(self):
        """Run the application."""
        self.show()


def launch_gui():
    """Launch the GUI application."""
    import sys
    app = QApplication(sys.argv)
    whisper.load_model("medium")  # Pre-load Whisper model
    gui = VideoProcessingGUI()
    gui.run()
    sys.exit(app.exec_())