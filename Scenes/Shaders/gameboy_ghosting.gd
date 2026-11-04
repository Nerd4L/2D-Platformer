extends ColorRect

var prev_tex: ImageTexture
var timer: float = 0.0
const GB_FRAME_TIME: float = 1.0 / 60 # Locks ghosting to 60fps even on a 144Hz monitor

func _ready() -> void:
	show()

func _process(delta: float) -> void:
	if not visible or not (material is ShaderMaterial):
		return

	timer += delta
	if timer >= GB_FRAME_TIME:
		timer = fmod(timer, GB_FRAME_TIME)

		var img: Image = get_viewport().get_texture().get_image()
		if not prev_tex:
			prev_tex = ImageTexture.create_from_image(img)
		else:
			prev_tex.update(img)

		(material as ShaderMaterial).set_shader_parameter("prev_frame_texture", prev_tex)
