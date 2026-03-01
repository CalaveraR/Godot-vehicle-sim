class_name SoundSystem
extends Node

onready var gear_engage = $GearEngage
onready var gear_grind = $GearGrind
onready var transmission_fail = $TransmissionFail
onready var vibration_sound = $Vibration
onready var warning_high = $WarningHigh
onready var warning_low = $WarningLow
onready var drivetrain_failure = $DrivetrainFailure

func play_sound(sound_name: String):
    match sound_name:
        "gear_engage":
            gear_engage.play()
        "gear_grind":
            gear_grind.play()
        "transmission_break":
            transmission_fail.play()
        "drivetrain_failure":
            drivetrain_failure.play()
        "warning_high":
            warning_high.play()
        "warning_low":
            warning_low.play()
        "vibration":
            if not vibration_sound.playing:
                vibration_sound.play()

func set_vibration_level(level: float):
    vibration_sound.volume_db = linear2db(clamp(level, 0.1, 1.0))
    vibration_sound.pitch_scale = 0.8 + (level * 0.4)
    
    if level < 0.1 and vibration_sound.playing:
        vibration_sound.stop()