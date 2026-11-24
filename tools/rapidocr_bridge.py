"""Run local RapidOCR and return line text and image coordinates as JSON."""
import contextlib
import json
import sys


def main():
    from rapidocr import RapidOCR

    sys.stdout.reconfigure(encoding="utf-8")

    # RapidOCR logs to stdout; reserve stdout for the response consumed by C#.
    with contextlib.redirect_stdout(sys.stderr):
        result = RapidOCR()(sys.argv[1])
    lines = []
    for text, points in zip(result.txts or (), result.boxes if result.boxes is not None else ()):
        xs = [float(point[0]) for point in points]
        ys = [float(point[1]) for point in points]
        lines.append({"text": text, "box": [min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)]})
    print(json.dumps({"lines": lines}, ensure_ascii=False))


if __name__ == "__main__":
    main()
