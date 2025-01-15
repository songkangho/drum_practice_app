# Score API (Backend)  
**음악 악보 API (백엔드)**  

This is the backend service for the **Score App**, developed using **FastAPI** and **OpenCV**.  
PDF나 이미지로 된 음악 악보를 처리하기 위한 **Score App**의 백엔드 서비스입니다. FastAPI와 OpenCV를 사용하여 개발되었습니다.  

---

## Features
- **Upload Music Scores**: Accepts images in formats like PNG and JPG.
- **Staff Line Detection**: Identifies staff lines and calculates bounding boxes.
- **Efficient API**: Built with FastAPI for fast and easy integration.
- **Flexible Format Support**: Processes images in multiple formats (JPEG, PNG).

---

## Tech Stack 

- **Framework**: FastAPI  
- **Image Processing**: OpenCV  
- **Language**: Python  
- **Response Format**: JSON  

---

## Installation

To set up the backend, follow these steps:  

### **1. Clone the Repository**
```bash
git clone https://github.com/songkangho/score_app.git
cd music-score-backend
```

### **2. Set Up a Virtual Environment**
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac용
venv\Scripts\activate     # Windows용
```

### **3. Install Dependencies**
```bash
pip install -r requirements.txt
```

### **4. Run the Server**
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
The server will be accessible at: [http://localhost:8000](http://localhost:8000)

---

## API Endpoints

### ***1. POST /process-image/***
Processes the uploaded image and detects staff lines.
업로드된 이미지를 처리하고 오선보를 감지합니다.

#### **Request**
- **Method**: `POST`  
- **URL**: `/process-image/`  
- **Headers**: 
  - `Content-Type: multipart/form-data`  
- **Body**: 
  - `file`: An image file (e.g., `.png`, `.jpg`).  
    이미지 파일 (.png, .jpg 등)

#### **Response**
Returns a JSON object containing:  
다음 내용을 포함하는 JSON 객체를 반환합니다:

- **`status`**: Request status (`success` or `error`).  
  
- **`rectangles`**: A list of detected staff line bounding boxes. Each bounding box contains:  
  
  - `top_left`: `[x, y]` coordinates of the top-left corner.  
      
  - `bottom_right`: `[x, y]` coordinates of the bottom-right corner.  
     

---

### Example Request
Upload an image to detect staff lines:  
```bash
curl -X POST "http://localhost:8000/process-image/" \
-H "Content-Type: multipart/form-data" \
-F "file=@path/to/your/image.png"
```

### Example Response
```json
{
  "status": "success",
  "rectangles": [
    {
      "top_left": [10, 20],
      "bottom_right": [300, 50]
    },
    {
      "top_left": [15, 60],
      "bottom_right": [310, 90]
    }
  ],
  "image_size": {
    "width": 1024,
    "height": 768
  }
}
```

---

## **Developer Information**

- **Developer**: Song Kang-ho  
- **Email**: zoom3901@gmail.com  
- **GitHub**: [songkangho](https://github.com/songkangho)
