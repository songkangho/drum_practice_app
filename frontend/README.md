# score_app(frontend)
A Flutter-based app that allows users to import and manage music scores from PDFs, configure metronome settings, and visualize score playback with precision.
PDF로 악보를 불러와서 저장하고, 메트로놈 및 BPM 설정과 오선보별 맞춤 설정이 가능한 Flutter 기반 앱입니다.

## Demo Video
[![App Demo](https://img.youtube.com/vi/qgYMwniyH2I/0.jpg)](https://www.youtube.com/watch?v=qgYMwniyH2I)


## Features
- **PDF Import & Score Management**  
  Users can import music scores in PDF format and store them within the app.  
  악보(PDF)를 불러와 앱 내에서 관리 및 저장이 가능합니다.

- **Staff Line Recognition**  
  Automatically recognizes staff lines within the PDF to process musical data.  
  PDF 파일에서 오선보를 자동으로 인식하여 데이터를 처리합니다.

- **Metronome Configuration**  
  Set and save metronome settings, including BPM (beats per minute).  
  Configure specific beats for each section of the music score.  
  메트로놈 설정(BPM 포함)을 저장할 수 있으며, 각 오선보 섹션별 비트 및 주기를 맞춤 설정할 수 있습니다.

- **Real-time Score Visualization**  
  While the metronome plays, the app highlights the current staff line in sync with the BPM and cycle.  
  메트로놈 재생 중 현재 진행 중인 오선보를 BPM 및 주기에 맞춰 실시간으로 표시합니다.


## Installation & Usage
1. Install Flutter from the [official site](https://flutter.dev).

2. Clone the repository:
    bash
    git clone https://github.com/your-username/music-score-app.git
    cd music-score-app

3. Install dependencies:
    flutter pub get

4. Run the app on an emulator or a connected device:
    flutter run

## Tech Stack
- Framework: Flutter
- Programming Language: Dart
- File Management: PDF handling with syncfusion_flutter_pdf
- Score Recognition: Custom algorithm for staff line detection
- State Management: Provider
- store Management : json file

## Project Structure
lib/
├── main.dart                 # Entry point of the application
├── screens/                  # UI screens for PDF management and score viewing
│   ├── pdf_grid_screen.dart  # Screen to display the list of imported PDFs
│   ├── score_view_screen.dart # Screen to view and interact with a selected score
├── services/                 # Logic and business services
│   ├── api_service.dart      # Handles communication with the backend (if any)
│   ├── metronome_service.dart # Metronome logic for managing BPM and playback
│   ├── pdf_image_service.dart # Logic to convert PDF pages to images for rendering
│   ├── storage_service.dart  # Handles local data storage (e.g., configurations, files)
├── utils/                    # Utility functions (common helpers)
.gitignore                    # Files and folders to ignore in Git
pubspec.yaml                  # Flutter dependencies and metadata

## How It Works
1. PDF Import
    Import music scores by selecting a PDF file from your device's storage.
    Use the app's built-in viewer to navigate through the score.

2. Staff Line Recognition
    Automatically detect and extract staff lines from the PDF for precise processing.

3. Metronome Configuration
    - Set BPM and specific cycles for different sections of the score.
    - Save configurations for future playback.

4. Real-time Playback
    - As the metronome runs, the app visually highlights the current staff line.
    - The playback speed and beat are synced to the user-defined BPM and cycle.

### Developer
 - Name: Song Kang-ho
 - Email: zoom3901@gmail.com
 - GitHub: songkangho