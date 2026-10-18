class_name DayNight
extends Node3D
## Sun, moon, sky, fog and weather. Drives the city's window and streetlight
## glow as night falls.

const NIGHT_TOP := Color("#04060f")
const NIGHT_HORIZON := Color("#121a2c")
const DAY_TOP := Color("#2f6fbf")
const DAY_HORIZON := Color("#b4cbe0")
const DUSK_HORIZON := Color("#e08a4a")

var hour := 10.0
var day_minutes := 16.0
var frozen := false
var weather := "clear"
var city: City
var follow: Node3D

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var world_env: WorldEnvironment
var rain: CPUParticles3D
var _flash_t := 0.0
var _thunder_t := 8.0


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = Game.settings["shadows"]
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.25
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.25
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	rain = CPUParticles3D.new()
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.7, 0.025)
	rain.mesh = drop
	rain.material_override = CharacterModel.mat(Color(0.7, 0.8, 0.95), 0.0, true, 0.45)
	rain.amount = 1800
	rain.lifetime = 1.4
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(45, 1, 45)
	rain.direction = Vector3(0.1, -1, 0)
	rain.spread = 3.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 32.0
	rain.initial_velocity_max = 38.0
	rain.emitting = false
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	add_to_group("settings_listeners")
	_apply()


func on_settings_changed() -> void:
	sun.shadow_enabled = Game.settings["shadows"]


func set_weather(w: String) -> void:
	weather = w
	rain.emitting = w == "rain" or w == "storm"
	_apply()


func _process(delta: float) -> void:
	if not frozen:
		hour = fmod(hour + delta * 24.0 / (day_minutes * 60.0), 24.0)
	if follow and is_instance_valid(follow):
		rain.global_position = follow.global_position + Vector3.UP * 25.0
	if weather == "storm":
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(6.0, 16.0)
			_flash_t = 0.25
			Sfx.play("explosion", null, -12.0, 0.3)
	_flash_t = maxf(0.0, _flash_t - delta)
	_apply()


func is_night() -> bool:
	return hour < 6.0 or hour > 19.0


func daylight() -> float:
	var elev := sin((hour - 6.0) / 12.0 * PI)
	return clampf(elev * 3.0 + 0.15, 0.0, 1.0)


func _apply() -> void:
	var elev := sin((hour - 6.0) / 12.0 * PI)
	var day := daylight()
	var dusk := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0)
	if elev >= 0.0:
		sun.rotation = Vector3(-(hour - 6.0) / 12.0 * PI, deg_to_rad(35.0), 0)
		sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.6, 0.35), dusk)
		sun.light_energy = lerpf(0.15, 1.25, day)
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	else:
		var night_h := fmod(hour + 6.0, 24.0)  # 18:00 -> 0, 06:00 -> 12
		sun.rotation = Vector3(-night_h / 12.0 * PI, deg_to_rad(-30.0), 0)
		sun.light_color = Color(0.62, 0.68, 0.85)
		sun.light_energy = 0.14
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	var top := NIGHT_TOP.lerp(DAY_TOP, day)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(DUSK_HORIZON, dusk * 0.7)
	var overcast := weather != "clear"
	if overcast:
		top = top.lerp(Color(0.25, 0.27, 0.3) * (0.3 + day * 0.7), 0.8)
		horizon = horizon.lerp(Color(0.35, 0.37, 0.4) * (0.3 + day * 0.7), 0.8)
		sun.light_energy *= 0.45
	if _flash_t > 0.0:
		top = top.lerp(Color.WHITE, 0.6)
		horizon = horizon.lerp(Color.WHITE, 0.6)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = top.darkened(0.5)
	env.ambient_light_color = horizon.lerp(Color(0.5, 0.53, 0.6), 0.5)
	env.ambient_light_energy = lerpf(0.3, 0.75, day) + (2.0 if _flash_t > 0.0 else 0.0)
	env.fog_light_color = horizon
	var view: float = Game.settings["view_distance"]
	env.fog_density = (0.006 if weather == "fog" else (0.0035 if overcast else 0.0011)) * (1200.0 / maxf(300.0, view))
	if city:
		city.set_night(1.0 - day)
