@echo off
rem Optional local RapidOCR environment for the source checkout.
setlocal
cd /d "%~dp0"
python -m venv rapidocr-env || exit /b 1
"rapidocr-env\Scripts\python.exe" -m pip install rapidocr==3.10.0 onnxruntime==1.32.0 pyinstaller==6.22.3 || exit /b 1
echo RapidOCR ready. Restart ClipShelf to use it.
