extends Button

@export var on_text: String
@export var off_text: String

func _ready() -> void:
	toggled.connect(update_text)

func update_text(on: bool) -> void:
	set_text(on_text if on else off_text)
