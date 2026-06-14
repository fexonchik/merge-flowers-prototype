extends Node

signal rewarded_ad_completed(reward_type)
signal rewarded_ad_failed(reward_type)
signal interstitial_closed(trigger_id)

func show_rewarded_ad(reward_type: String) -> void:
	print("[Ads] Rewarded ad requested:", reward_type)
	call_deferred("_emit_rewarded_success", reward_type)

func show_interstitial_ad(trigger_id: String) -> void:
	print("[Ads] Interstitial requested:", trigger_id)
	call_deferred("_emit_interstitial_closed", trigger_id)

func _emit_rewarded_success(reward_type: String) -> void:
	rewarded_ad_completed.emit(reward_type)

func _emit_interstitial_closed(trigger_id: String) -> void:
	interstitial_closed.emit(trigger_id)
