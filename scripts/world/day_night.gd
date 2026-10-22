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
var indoors := false:
	set(v):
		if v == indoors:
			return
		indoors = v
		# Rain and snow start (or stop) when you step outside (or in).
		if rain and snow:
			_update_precip()

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var world_env: WorldEnvironment
var rain: CPUParticles3D
var snow: CPUParticles3D
var local_weather := ""     # e.g. Gotham's rain, set per island
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
	snow = CPUParticles3D.new()
	var flake := SphereMesh.new()
	flake.radius = 0.05
	flake.height = 0.1
	snow.mesh = flake
	snow.material_override = CharacterModel.mat(Color(1, 1, 1), 0.0, true, 0.9)
	snow.amount = 1500
	snow.lifetime = 6.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(45, 1, 45)
	snow.direction = Vector3(0.2, -1, 0.1)
	snow.spread = 20.0
	snow.gravity = Vector3.ZERO
	snow.initial_velocity_min = 2.5
	snow.initial_velocity_max = 4.0
	snow.emitting = false
	add_child(snow)
	add_to_group("settings_listeners")
	_apply()


func on_settings_changed() -> void:
	sun.shadow_enabled = Game.settings["shadows"]


func set_weather(w: String) -> void:
	weather = w
	_update_precip()
	_apply()


func _effective() -> String:
	return local_weather if weather == "clear" and local_weather != "" else weather


func _update_precip() -> void:
	var w := _effective()
	rain.emitting = (w == "rain" or w == "storm") and not indoors
	snow.emitting = w == "snow" and not indoors


func _process(delta: float) -> void:
	if not frozen:
		hour = fmod(hour + delta * 24.0 / (day_minutes * 60.0), 24.0)
	if follow and is_instance_valid(follow):
		rain.global_position = follow.global_position + Vector3.UP * 25.0
		snow.global_position = follow.global_position + Vector3.UP * 18.0
		# Gotham always seems to be raining.
		var lw := ""
		if city:
			var isl := city.island_at(follow.global_position)
			if not isl.is_empty():
				lw = str(isl["style"].get("weather", ""))
		if lw != local_weather:
			local_weather = lw
			_update_precip()
	if _effective() == "storm":
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
	var overcast := _effective() != "clear"
	if overcast:
		top = top.lerp(Color(0.25, 0.27, 0.3) * (0.3 + day * 0.7), 0.8)
		horizon = horizon.lerp(Color(0.35, 0.37, 0.4) * (0.3 + day * 0.7), 0.8)
		sun.light_energy *= 0.45
	var spec: Dictionary = city.spec if city else {}
	var island_look: Dictionary = {}
	if city and follow and is_instance_valid(follow) and not spec.has("sky"):
		var isl := city.island_at(follow.global_position)
		if not isl.is_empty() and isl["style"].has("sky"):
			island_look = isl["style"]
	if spec.has("sky") or island_look.has("sky"):
		var look: Array = spec["sky"] if spec.has("sky") else island_look["sky"]
		var amt := float(look[2])
		top = top.lerp(Color(str(look[0])) * (0.35 + day * 0.65), amt)
		horizon = horizon.lerp(Color(str(look[1])) * (0.35 + day * 0.65), amt)
	if spec.has("sun"):
		sun.light_color = sun.light_color.lerp(Color(str(spec["sun"])), 0.6)
	# Space: a black sky and a hard white sun whatever the hour. Climbing high
	# above Earth fades the sky toward it.
	var space_t := 1.0 if spec.get("space", false) else 0.0
	if space_t == 0.0 and city and city.kind == "metro" and follow and is_instance_valid(follow):
		space_t = clampf((follow.global_position.y - 250.0) / 450.0, 0.0, 1.0)
	if space_t > 0.0:
		top = top.lerp(Color(0.0, 0.0, 0.015), space_t)
		horizon = horizon.lerp(Color(0.02, 0.04, 0.1), space_t * 0.85)
		if spec.get("space", false):
			sun.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(40.0), 0)
			sun.light_color = Color(1, 0.98, 0.94)
			sun.light_energy = 1.4
			day = 1.0
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
	env.fog_density = (0.006 if _effective() == "fog" else (0.003 if overcast else 0.0007)) * (1200.0 / maxf(300.0, view)) * float(spec.get("haze", island_look.get("haze", 1.0))) * (1.0 - space_t * 0.85)
	env.fog_enabled = not indoors
	if indoors:
		sun.light_energy = 0.0
		env.ambient_light_color = Color(0.55, 0.57, 0.62)
		env.ambient_light_energy = 0.55
	if follow and is_instance_valid(follow):
		rain.visible = not indoors
		snow.visible = not indoors
	if city:
		city.set_night(1.0 - day)
