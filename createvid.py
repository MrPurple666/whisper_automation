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


def whisper_to_srt(whisper_result, subtitles_path):
    """Converte a transcrição do Whisper para o formato SRT."""
    with open(subtitles_path, "w", encoding="utf-8") as f:
        for i, segment in enumerate(whisper_result["segments"]):
            start = segment["start"]
            end = segment["end"]
            text = segment["text"].strip()

            # Converter para formato HH:MM:SS,MMM
            def format_time(seconds):
                hours = int(seconds // 3600)
                minutes = int((seconds % 3600) // 60)
                secs = seconds % 60
                millis = int((secs - int(secs)) * 1000)
                return f"{hours:02d}:{minutes:02d}:{int(secs):02d},{millis:03d}"

            f.write(f"{i + 1}\n")
            f.write(f"{format_time(start)} --> {format_time(end)}\n")
            f.write(f"{text}\n\n")


def generate_subtitles(input_path, model="medium"):
    """Gera legendas usando Whisper e salva no formato SRT."""
    print("Carregando o modelo Whisper...")
    whisper_model = whisper.load_model(model)
    print("Transcrevendo o áudio do vídeo...")
    result = whisper_model.transcribe(input_path)

    subtitles_path = "subtitles.srt"
    whisper_to_srt(result, subtitles_path)
    print("Legendas geradas com sucesso.")
    return subtitles_path


def validate_srt_format(subtitles_path):
    """Valida o formato SRT."""
    with open(subtitles_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        if "-->" in line:
            timestamps = line.split("-->")
            if len(timestamps) != 2:
                raise ValueError(f"Erro no formato de tempo na linha {i + 1}: {line}")
    print("Arquivo .srt validado com sucesso.")


def add_subtitles(video_path, subtitles_path, output_path="final_output.mp4"):
    """Adiciona legendas ao vídeo usando FFmpeg."""
    if not os.path.exists(subtitles_path):
        raise FileNotFoundError("O arquivo de legendas 'subtitles.srt' não foi encontrado.")
    
    # Validar o formato do arquivo SRT
    validate_srt_format(subtitles_path)

    # Caminho absoluto para evitar problemas
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
