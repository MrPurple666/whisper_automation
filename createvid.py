import os
import subprocess
from yt_dlp import YoutubeDL
import whisper

def download_video(video_url, output_path="video.mp4"):
    """Baixa o vídeo do YouTube usando yt-dlp."""
    ydl_opts = {
        'format': 'mp4',
        'outtmpl': output_path
    }
    with YoutubeDL(ydl_opts) as ydl:
        ydl.download([video_url])
    return output_path

def cut_video(input_path, start_time, end_time, output_path="output.mp4"):
    """Corta o vídeo usando FFmpeg para o formato vertical."""
    command = [
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
    subprocess.run(command, check=True)
    return output_path

def generate_subtitles(input_path, model="medium"):
    """Gera legendas usando Whisper."""
    print("Carregando o modelo Whisper...")
    whisper_model = whisper.load_model(model)
    print("Transcrevendo o áudio do vídeo...")
    result = whisper_model.transcribe(input_path)
    subtitles_path = "subtitles.srt"
    with open(subtitles_path, "w") as f:
        f.write(result["text"])
    print("Legendas geradas com sucesso.")
    return subtitles_path

def add_subtitles(video_path, subtitles_path, output_path="final_output.mp4"):
    """Adiciona legendas ao vídeo usando FFmpeg."""
    command = [
        "ffmpeg",
        "-i", video_path,
        "-vf", f"subtitles={subtitles_path}",
        "-c:v", "libx264",
        "-crf", "23",
        "-preset", "fast",
        "-c:a", "aac",
        output_path
    ]
    subprocess.run(command, check=True)
    return output_path

def main():
    # Pede o link do vídeo
    video_url = input("Digite o link do vídeo do YouTube: ")
    
    # Baixa o vídeo
    print("Baixando o vídeo...")
    input_video = download_video(video_url)
    
    # Pede os tempos de corte
    start_time = input("Digite o tempo de início (formato HH:MM:SS): ")
    end_time = input("Digite o tempo de término (formato HH:MM:SS): ")
    
    # Corta o vídeo
    print("Cortando o vídeo para o formato Shorts...")
    cut_video_path = "short_video.mp4"
    cut_video(input_video, start_time, end_time, cut_video_path)
    
    # Gera legendas
    print("Gerando legendas com o modelo medium do Whisper...")
    subtitles_path = generate_subtitles(cut_video_path, model="medium")
    
    # Adiciona legendas ao vídeo
    print("Adicionando legendas ao vídeo...")
    final_video_path = "final_short.mp4"
    add_subtitles(cut_video_path, subtitles_path, final_video_path)
    
    print(f"Vídeo final criado: {final_video_path}")

if __name__ == "__main__":
    main()
