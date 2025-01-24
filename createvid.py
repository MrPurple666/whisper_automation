import os
import logging
from typing import Optional, Dict, Any
from yt_dlp import YoutubeDL
import whisper
from ffmpeg import FFmpeg, Progress

# Configuração do logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def baixar_video(video_url: str, output_path: str = "video.mp4") -> str:
    """Baixa um vídeo do YouTube usando yt-dlp."""
    ydl_opts = {'format': 'mp4', 'outtmpl': output_path}
    try:
        with YoutubeDL(ydl_opts) as ydl:
            ydl.download([video_url])
        logger.info(f"Vídeo baixado com sucesso: {output_path}")
        return output_path
    except Exception as e:
        logger.error(f"Falha ao baixar o vídeo: {e}")
        raise

def cortar_video(input_path: str, start_time: str, end_time: str, output_path: str = "output.mp4") -> str:
    """Corta o vídeo para o formato vertical usando python-ffmpeg."""
    try:
        ffmpeg = (
            FFmpeg()
            .input(input_path, ss=start_time, to=end_time)
            .filter("scale", 1080, 1920)  # Formato vertical (1080x1920)
            .filter("setsar", 1, 1)       # Mantém a proporção de pixel
            .output(
                output_path,
                vcodec="libx264",         # Codec de vídeo
                preset="fast",            # Preset de codificação
                crf=23,                   # Qualidade do vídeo
                acodec="aac",             # Codec de áudio
                strict="experimental",    # Modo experimental para codecs
            )
            .overwrite_output()           # Sobrescreve o arquivo de saída se existir
        )

        # Opcional: Acompanhamento do progresso
        @ffmpeg.on("progress")
        def on_progress(progress: Progress):
            logger.info(f"Processando frame {progress.frame} de {progress.total_frames}")

        ffmpeg.execute()
        logger.info(f"Vídeo cortado com sucesso: {output_path}")
        return output_path
    except Exception as e:
        logger.error(f"Falha ao cortar o vídeo: {e}")
        raise

def whisper_para_srt(whisper_result: Dict[str, Any], subtitles_path: str) -> None:
    """Converte a transcrição do Whisper para o formato SRT."""
    try:
        with open(subtitles_path, "w", encoding="utf-8") as f:
            for i, segment in enumerate(whisper_result["segments"]):
                start = segment["start"]
                end = segment["end"]
                texto = segment["text"].strip()

                def formatar_tempo(seconds: float) -> str:
                    horas = int(seconds // 3600)
                    minutos = int((seconds % 3600) // 60)
                    segundos = seconds % 60
                    milissegundos = int((segundos - int(segundos)) * 1000)
                    return f"{horas:02d}:{minutos:02d}:{int(segundos):02d},{milissegundos:03d}"

                f.write(f"{i + 1}\n")
                f.write(f"{formatar_tempo(start)} --> {formatar_tempo(end)}\n")
                f.write(f"{texto}\n\n")
        logger.info(f"Legendas geradas com sucesso: {subtitles_path}")
    except Exception as e:
        logger.error(f"Falha ao gerar legendas: {e}")
        raise

def gerar_legendas(input_path: str, model: str = "medium") -> str:
    """Gera legendas usando o Whisper."""
    logger.info("Carregando o modelo Whisper...")
    try:
        whisper_model = whisper.load_model(model)
        logger.info("Transcrevendo o áudio...")
        resultado = whisper_model.transcribe(input_path)
        subtitles_path = "legendas.srt"
        whisper_para_srt(resultado, subtitles_path)
        return subtitles_path
    except Exception as e:
        logger.error(f"Falha ao transcrever o áudio: {e}")
        raise

def validar_formato_srt(subtitles_path: str) -> None:
    """Valida o formato do arquivo SRT."""
    try:
        with open(subtitles_path, 'r', encoding='utf-8') as f:
            linhas = f.readlines()
        
        for i, linha in enumerate(linhas):
            if "-->" in linha:
                timestamps = linha.split("-->")
                if len(timestamps) != 2:
                    raise ValueError(f"Formato de tempo inválido na linha {i + 1}: {linha}")
        logger.info("Arquivo SRT validado com sucesso.")
    except Exception as e:
        logger.error(f"Falha ao validar o arquivo SRT: {e}")
        raise

def adicionar_legendas(video_path: str, subtitles_path: str, output_path: str = "final_output.mp4") -> str:
    """Adiciona legendas ao vídeo usando python-ffmpeg."""
    try:
        validar_formato_srt(subtitles_path)
        caminho_absoluto_legendas = os.path.abspath(subtitles_path)

        ffmpeg = (
            FFmpeg()
            .input(video_path)
            .output(
                output_path,
                vf=f"subtitles='{caminho_absoluto_legendas}'",  # Filtro de legendas
                vcodec="libx264",  # Codec de vídeo
                crf=23,            # Qualidade do vídeo
                preset="fast",     # Preset de codificação
                acodec="aac",      # Codec de áudio
            )
            .overwrite_output()    # Sobrescreve o arquivo de saída se existir
        )

        # Opcional: Acompanhamento do progresso
        @ffmpeg.on("progress")
        def on_progress(progress: Progress):
            logger.info(f"Processando frame {progress.frame} de {progress.total_frames}")

        ffmpeg.execute()
        logger.info(f"Legendas adicionadas com sucesso: {output_path}")
        return output_path
    except Exception as e:
        logger.error(f"Falha ao adicionar legendas: {e}")
        raise

def main() -> None:
    """Função principal para processar o vídeo."""
    try:
        video_url = input("Digite o link do vídeo do YouTube: ")
        
        logger.info("Baixando o vídeo...")
        input_video = baixar_video(video_url)
        
        start_time = input("Digite o tempo de início (formato HH:MM:SS): ")
        end_time = input("Digite o tempo de término (formato HH:MM:SS): ")
        
        logger.info("Cortando o vídeo para o formato Shorts...")
        cut_video_path = "short_video.mp4"
        cortar_video(input_video, start_time, end_time, cut_video_path)
        
        logger.info("Gerando legendas com o modelo medium do Whisper...")
        subtitles_path = gerar_legendas(cut_video_path)
        
        logger.info("Adicionando legendas ao vídeo...")
        final_video_path = "final_short.mp4"
        adicionar_legendas(cut_video_path, subtitles_path, final_video_path)
        
        logger.info(f"Vídeo final criado: {final_video_path}")
    except Exception as e:
        logger.error(f"Erro durante o processamento: {e}")

if __name__ == "__main__":
    main()
