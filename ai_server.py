import cv2
import math
from ultralytics import YOLO
import requests

# 1. טעינת מודל ה-AI - רץ אוטומטית על כרטיס המסך (NVIDIA CUDA) במידה וקיים
model = YOLO('yolov8n.pt') 

# 2. הגדרת מקור הוידאו - שים פה קובץ וידאו אמיתי של משחק וקרא לו match.mp4
video_path = "C:/ronben_tennis/match.mp4"
cap = cv2.VideoCapture(video_path)

# גבולות המגרש הפיזיים בתוך הוידאו (להתאמה לפי זווית הצילום)
court_left = 100
court_right = 500
court_top = 200
court_bottom = 600

# משתני מעקב וקטוריים
last_x, last_y = None, None
is_padel = False  # שנה ל-True אם אתה מריץ משחק פאדל

print("=== RONBEN TENNIS AI CORE ONLINE ===")
print("CONNECTING TO HARDWARE: NVIDIA GPU ACCELERATION ACTIVE")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        print("END OF VIDEO STREAM OR FILE NOT FOUND")
        break

    # הרצת מודל ה-YOLOv8 על הפריים במהירות מקסימלית
    results = model(frame, verbose=False)
    
    for box in results[0].boxes:
        # קוד class 32 ב-YOLOv8 מייצג sports ball (כדור טניס/פאדל)
        if int(box.cls[0]) == 32:
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            current_x = (x1 + x2) / 2
            current_y = (y1 + y2) / 2
            
            # אלגוריתם זיהוי Bounce (שינוי כיוון תנועה פתאומי בציר ה-Y)
            if last_y is not None:
                # מדמה שינוי וקטור (כדור נע למטה ופתאום עולה למעלה)
                if current_y < last_y and (last_y - currentY) > 2:
                    
                    # חישוב אם מיקום הפגיעה חרג מקווי המגרש
                    is_outside = (current_x < court_left or current_x > court_right or 
                                  current_y < court_top or current_y > court_bottom)
                    
                    # לוגיקת פאדל מול טניס
                    hit_wall_directly = False
                    if is_padel and is_outside:
                        # בפאדל: אם הפגיעה גבוהה מדי, זה אומר פגיעה ישירה בקיר/זכוכית
                        if current_y < court_top + 40:
                            hit_wall_directly = True

                    # אריזת הנתונים ושליחתם בזמן אמת לטלפון/לאפליקציה
                    payload = {
                        "x": current_x,
                        "y": current_y,
                        "isOut": is_outside,
                        "hitWallDirectly": hit_wall_directly
                    }
                    
                    try:
                        # שליחת אירוע הפגיעה לשרת של פלאטר ב-Localhost
                        requests.post("http://localhost:8080/ball-impact", json=payload, timeout=0.05)
                        print(f"IMPACT REGISTERED // X: {current_x:.1f}, Y: {current_y:.1f} // OUT: {is_outside}")
                    except requests.exceptions.RequestException:
                        pass # האפליקציה עדיין לא מקשיבה, ממשיך להריץ
                        
            last_x = current_x
            last_y = current_y

cap.release()