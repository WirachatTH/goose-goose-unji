from PIL import Image
import os
import math

# --- 1. CONFIGURATION ---
INPUT_PNG_FILE = 'sprite.png'  # 💡 ชื่อไฟล์ PNG ต้นฉบับของคุณ
OUTPUT_MEM_FILE = 'sprite.mem'   # 💡 ชื่อไฟล์ .mem ที่จะสร้างขึ้นมา

# --- 2. CONVERSION FUNCTION ---

def convert_png_to_mem_simple():
    try:
        # 💡 ใช้ convert("RGB") เพื่อให้แน่ใจว่าไม่มี Alpha Channel
        img = Image.open(INPUT_PNG_FILE).convert("RGB") 
    except FileNotFoundError:
        print(f"Error: File '{INPUT_PNG_FILE}' not found.")
        return

    width, height = img.size
    total_pixels = width * height
    print(f"Processing image: {width}x{height} pixels ({total_pixels} total)")
    
    # 💡 เปิดไฟล์ .mem สำหรับเขียน
    with open(OUTPUT_MEM_FILE, 'w') as f_out:
        
        # 💡 วนรอบพิกเซลตามลำดับ
        for y in range(height):
            for x in range(width):
                r_8bit, g_8bit, b_8bit = img.getpixel((x, y))
                
                # 3. Scaling 8-bit (0-255) down to 4-bit (0-15)
                # 💡 ใช้ math.floor (ปัดลง) หรือ math.round (ปัดตามปกติ)
                # การใช้ math.floor(value / 16) เป็นวิธีที่ง่ายและปลอดภัยที่สุดในการลดค่า
                r_4bit = math.floor(r_8bit / 16)
                g_4bit = math.floor(g_8bit / 16)
                b_4bit = math.floor(b_8bit / 16)

                # 4. รวม 4-bit RGB เป็นค่า 12-bit Hex
                # (R[11:8] G[7:4] B[3:0])
                hex_value = (r_4bit << 8) | (g_4bit << 4) | b_4bit
                
                # 5. เขียนค่า Hex ลงในไฟล์ .mem (3 หลัก Hex: 000 ถึง FFF)
                f_out.write(f'{hex_value:03X}\n')

    print(f"Success! {total_pixels} pixels converted to {OUTPUT_MEM_FILE}")
    print("Add char_atlas.mem to your Vivado project sources and use $readmemh.")

if __name__ == '__main__':
    convert_png_to_mem_simple()