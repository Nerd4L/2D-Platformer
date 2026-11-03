@tool
extends EditorScript

const SOURCE_IMAGE_PATH: String = "res://Images/Environment/terrain.png"
const OUTPUT_IMAGE_PATH: String = "res://Images/Environment/tileset_8x8_clean.png"

func _run() -> void:
	# 1. Load texture
	var tex := load(SOURCE_IMAGE_PATH) as Texture2D
	if not tex:
		print("ERROR: Could not load texture at: ", SOURCE_IMAGE_PATH)
		return

	# 2. Extract image data and force RGBA8 format so formats match 100%!
	var src_img: Image = tex.get_image()
	if src_img.is_compressed():
		src_img.decompress()
	src_img.convert(Image.FORMAT_RGBA8)

	# 3. Create the clean 512x256 image in the exact same format
	var clean_img := Image.create(512, 256, false, Image.FORMAT_RGBA8)

	for row in range(16):
		for col in range(32):
			var src_x: int = 1 + col * 18
			var src_y: int = 1 + row * 18

			var dest_x: int = col * 16
			var dest_y: int = row * 16

			clean_img.blit_rect(src_img, Rect2i(src_x, src_y, 16, 16), Vector2i(dest_x, dest_y))

	# 4. Save to disk
	var output_os_path: String = ProjectSettings.globalize_path(OUTPUT_IMAGE_PATH)
	var err := clean_img.save_png(output_os_path)

	if err == OK:
		print("SUCCESS: Clean 512x256 image created at %s!" % OUTPUT_IMAGE_PATH)
		EditorInterface.get_resource_filesystem().scan()
	else:
		print("ERROR saving PNG: ", err)
