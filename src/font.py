# Use this script to generate a font tile image for HL1 HUD numbers.
# The output image will be an 8-bit BMP file with each digit (0-9), use HLMV to import into the existing model number
import sys
from PIL import Image, ImageDraw, ImageFont

FONT_FILE = "Michroma.ttf" 

FONT_SIZE = 54
FONT_COLOR = (255, 255, 255)

OUTPUT_FILE = "font_tiles.bmp"

# HL1 model uses 50x51 size for each character tile (0-9)
CHARS_TO_DRAW = "0123456789"
CHAR_WIDTH = 50
CHAR_HEIGHT = 51
IMAGE_WIDTH = CHAR_WIDTH * len(CHARS_TO_DRAW)
IMAGE_HEIGHT = CHAR_HEIGHT

def generate_image():
    print(f"Loading font from: {FONT_FILE}")
    
    try:
        font = ImageFont.truetype(FONT_FILE, FONT_SIZE)
    except IOError:
        print(f"Error: Could not load font file at '{FONT_FILE}'.")
        print("Please check the FONT_FILE path in the script.")
        sys.exit(1)

    print("Creating blank 8-bit image...")
    image = Image.new('RGB', (IMAGE_WIDTH, IMAGE_HEIGHT), color=0)
    draw = ImageDraw.Draw(image)

    print(f"Drawing characters: {CHARS_TO_DRAW}")
    
    for i, char in enumerate(CHARS_TO_DRAW):
        tile_x_start = i * CHAR_WIDTH
        tile_center_x = tile_x_start + (CHAR_WIDTH / 2)
        tile_center_y = CHAR_HEIGHT / 2

        try:
            draw.text(
                (tile_center_x, tile_center_y),
                char,
                font=font,
                fill=FONT_COLOR,  # Use the new color variable
                anchor="mm" 
            )
        except ImportError:
            # Fallback for older Pillow versions that don't support 'anchor'
            print("Warning: Pillow version is old. Text may not be perfectly centered.")
            # Simple top-left draw (less accurate centering)
            draw.text((tile_x_start + 5, 5), char, font=font, fill=0)

    print("Converting 'RGB' image to 8-bit 'P' (paletted) mode...")
    image = image.convert('P')

    print(f"Saving image to: {OUTPUT_FILE}")
    image.save(OUTPUT_FILE, format="BMP")
    print("Done!")

if __name__ == "__main__":
    generate_image()