from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import cv2
import numpy as np
import os
from typing import List
#import matplotlib.pyplot as plt

app = FastAPI()

def detect_staff_and_vertical_lines_from_array(image_array: np.ndarray):
    """
    Detects staff lines from an image array instead of a file path.
    """
    # 1. Convert the array to grayscale
    image = cv2.cvtColor(image_array, cv2.COLOR_BGR2GRAY)

    # 2. Apply binary thresholding with OTSU method
    _, binary = cv2.threshold(image, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # 3. Detect staff lines using the helper function
    staff_image, staff_bounding_boxes = detect_staff_lines(image, binary)

    for i, (x_min, y_min, x_max, y_max) in enumerate(staff_bounding_boxes, start=1):
        print(f"Staff {i}: Top-Left ({x_min}, {y_min}), Bottom-Right ({x_max}, {y_max})")

    #Display final result
    #plt.figure(figsize=(12, 8))
    #plt.imshow(cv2.cvtColor(staff_image, cv2.COLOR_BGR2RGB))
    #plt.title("Filtered Staff Lines (Red)")
    #plt.axis("off")
    #plt.show()

    return staff_image, staff_bounding_boxes

def detect_staff_lines(image, binary):
    """
    기존 작성된 detect_staff_lines 함수 그대로 유지.
    """
    horizontal_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (50, 1))
    horizontal_lines = cv2.morphologyEx(binary, cv2.MORPH_OPEN, horizontal_kernel, iterations=2)

    horizontal_edges = cv2.Canny(horizontal_lines, 50, 150)
    staff_lines = cv2.HoughLinesP(horizontal_edges, rho=1, theta=np.pi / 180,
                                  threshold=100, minLineLength=100, maxLineGap=20)

    result_image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)

    filtered_staff_lines = []
    if staff_lines is not None:
        line_lengths = [np.sqrt((x2 - x1)**2 + (y2 - y1)**2) for x1, y1, x2, y2 in staff_lines[:, 0]]
        mean_length = np.mean(line_lengths)
        for i, line in enumerate(staff_lines):
            x1, y1, x2, y2 = line[0]
            if line_lengths[i] >= 0.7 * mean_length:
                filtered_staff_lines.append((x1, y1, x2, y2))
                cv2.line(result_image, (x1, y1), (x2, y2), (0, 0, 255), 2)

    staff_bounding_boxes = []
    if filtered_staff_lines:
        filtered_staff_lines.sort(key=lambda line: line[1])
        current_group = [filtered_staff_lines[0]]

        for i in range(1, len(filtered_staff_lines)):
            _, y1, _, _ = filtered_staff_lines[i]
            _, prev_y1, _, prev_y2 = current_group[-1]

            if abs(y1 - prev_y1) <= 15:
                current_group.append(filtered_staff_lines[i])
            else:
                x_min = min(line[0] for line in current_group)
                x_max = max(line[2] for line in current_group)
                y_min = min(line[1] for line in current_group)
                y_max = max(line[1] for line in current_group)
                staff_bounding_boxes.append((x_min, y_min, x_max, y_max))
                current_group = [filtered_staff_lines[i]]

        if current_group:
            x_min = min(line[0] for line in current_group)
            x_max = max(line[2] for line in current_group)
            y_min = min(line[1] for line in current_group)
            y_max = max(line[1] for line in current_group)
            staff_bounding_boxes.append((x_min, y_min, x_max, y_max))

    for (x_min, y_min, x_max, y_max) in staff_bounding_boxes:
        cv2.rectangle(result_image, (x_min, y_min), (x_max, y_max), (0, 255, 255), 2)

    return result_image, staff_bounding_boxes


@app.post("/process-image/")
async def detect_rectangles(file: UploadFile = File(...)):
    """
    이미지 파일을 업로드 받아 오선 및 사각형 탐지를 수행하고 결과를 반환하는 API.
    """
    try:
        # 1. 파일 읽기
        contents = await file.read()
        np_array = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(np_array, cv2.IMREAD_COLOR)

        if image is None:
            return JSONResponse(content={"status": "error", "message": "Failed to decode image. Invalid file format."}, status_code=400)

        # 2. Detect staff lines and bounding boxes
        _, rectangles = detect_staff_and_vertical_lines_from_array(image)

        # 3. NumPy 데이터 -> Python 기본 데이터 타입 변환
        rectangles = [
            {
                "top_left": [int(x_min), int(y_min)],
                "bottom_right": [int(x_max), int(y_max)]
            }
            for (x_min, y_min, x_max, y_max) in rectangles
        ]

        print(f"Rectangles: {rectangles}")  # 디버깅: 서버에서 반환하는 좌표 확인

        # 4. 이미지 원본 크기 반환
        image_height, image_width = image.shape[:2]
        return JSONResponse(content={
            "status": "success",
            "rectangles": rectangles,
            "image_size": {"width": image_width, "height": image_height}
        })

    except Exception as e:
        print(f"Error occurred: {e}")  # 디버깅: 에러 메시지 출력
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
