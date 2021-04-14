extends BasicModel

# VRM guarantees neck and spine to exist
# These might not be named exactly 'neck' and 'spine', so this is best effort only
const NECK_BONE = "neck"
const SPINE_BONE = "spine"

onready var neck_bone_id: int = skeleton.find_bone(NECK_BONE)
onready var spine_bone_id: int = skeleton.find_bone(SPINE_BONE)

var eco_mode: bool = false

var stored_offsets: ModelDisplayScreen.StoredOffsets

var vrm_mappings: VRMMappings
var left_eye_id: int
var right_eye_id: int

var mapped_meshes: Dictionary

# Blinking
var blink_threshold: float = 0.3
var eco_mode_is_blinking: bool = false

# Gaze
var gaze_strength: float = 0.5

# Mouth
var min_mouth_value: float = 0.0

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	translation_damp = 0.1
	rotation_damp = 0.01
	additional_bone_damp = 0.6

	# TODO this is gross
	stored_offsets = get_parent().get_parent().stored_offsets

	# Read vrm mappings
	has_custom_update = true
	if vrm_mappings.head != HEAD_BONE:
		head_bone_id = skeleton.find_bone(vrm_mappings.head)
	left_eye_id = skeleton.find_bone(vrm_mappings.left_eye)
	right_eye_id = skeleton.find_bone(vrm_mappings.right_eye)
	for mesh_name in vrm_mappings.meshes_used:
		mapped_meshes[mesh_name] = find_node(mesh_name) as MeshInstance

	if not neck_bone_id:
		AppManager.log_message("Neck bone not found. Is this a .vrm model?")
	if not spine_bone_id:
		AppManager.log_message("Spine bone not found. Is this a .vrm model?")
	
	additional_bones_to_pose_names.append(NECK_BONE)
	additional_bones_to_pose_names.append(SPINE_BONE)

	scan_mapped_bones()

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

static func _to_godot_quat(v: Quat) -> Quat:
	return Quat(v.x, -v.y, v.z, v.w)

func _modify_blend_shape(mesh_instance: MeshInstance, blend_shape: String, value: float) -> void:
	mesh_instance.set("blend_shapes/%s" % blend_shape, value)

###############################################################################
# Public functions                                                            #
###############################################################################

func set_expression(expression_name: String, expression_weight: float) -> void:
	for mesh_name in vrm_mappings[expression_name].get_meshes():
		for blend_name in vrm_mappings[expression_name].expression_data[mesh_name]:
			_modify_blend_shape(mapped_meshes[mesh_name], blend_name, expression_weight)

func custom_update(data: OpenSeeGD.OpenSeeData, interpolation_data: InterpolationData) -> void:
	# NOTE: Eye mappings are intentionally reversed so that the model mirrors the data
	# TODO i think this can be made more efficient
	if not eco_mode:
		# Left eye blinking
		if data.left_eye_open >= blink_threshold:
			set_expression("blink_r", 1.0 - data.left_eye_open)
		else:
			set_expression("blink_r", 1.0)

		# Right eye blinking
		if data.right_eye_open >= blink_threshold:
			set_expression("blink_l", 1.0 - data.left_eye_open)
		else:
			set_expression("blink_l", 1.0)

		# TODO eyes are a bit wonky
		# Left eye gaze
		var left_eye_transform: Transform = Transform()
		var left_eye_rotation: Vector3 = interpolation_data.interpolate(InterpolationData.InterpolationDataType.LEFT_EYE_ROTATION, gaze_strength)
		left_eye_transform = left_eye_transform.rotated(Vector3.RIGHT, -left_eye_rotation.x)
		left_eye_transform = left_eye_transform.rotated(Vector3.UP, left_eye_rotation.y)
		if Input.is_key_pressed(KEY_0): AppManager.log_message(str(left_eye_rotation))
		skeleton.set_bone_pose(right_eye_id, left_eye_transform)
		
		# Right eye gaze
		var right_eye_transform: Transform = Transform()
		var right_eye_rotation: Vector3 = interpolation_data.interpolate(InterpolationData.InterpolationDataType.RIGHT_EYE_ROTATION, gaze_strength)
		right_eye_transform = right_eye_transform.rotated(Vector3.RIGHT, -right_eye_rotation.x)
		right_eye_transform = right_eye_transform.rotated(Vector3.UP, right_eye_rotation.y)
		if Input.is_key_pressed(KEY_1): AppManager.log_message(str(right_eye_rotation))
		skeleton.set_bone_pose(left_eye_id, right_eye_transform)
		
		# Mouth tracking
		set_expression("a", min(max(min_mouth_value, data.features.mouth_open * 2.0), 1.0))
	else:
		# TODO implement eco mode, should be more efficient than standard mode
		# Eco-mode blinking
		if(data.left_eye_open < blink_threshold and data.right_eye_open < blink_threshold):
			pass
		else:
			pass
