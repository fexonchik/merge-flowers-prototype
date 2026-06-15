extends Node

signal rewarded_ad_completed(reward_type)
signal rewarded_ad_failed(reward_type)
signal interstitial_closed(trigger_id, was_shown)

var _rewarded_pending := false
var _rewarded_type := ""
var _rewarded_was_rewarded := false
var _interstitial_pending := false
var _interstitial_trigger_id := ""

func show_rewarded_ad(reward_type: String) -> void:
	if _rewarded_pending:
		print("[Ads] Rewarded already pending, ignore:", reward_type)
		return
	_rewarded_pending = true
	_rewarded_type = reward_type
	_rewarded_was_rewarded = false
	print("[Ads] Rewarded ad requested:", reward_type)

	if _can_use_yandex_ads():
		var escaped_reward_type := JSON.stringify(reward_type)
		var js := """
(function() {
	if (typeof ysdk === 'undefined' || !ysdk.adv || !ysdk.adv.showRewardedVideo) {
		return false;
	}
	var rewardType = %s;
	ysdk.adv.showRewardedVideo({
		callbacks: {
			onOpen: function() {
				console.log('[YG Ads] Rewarded opened:', rewardType);
			},
			onRewarded: function() {
				console.log('[YG Ads] Rewarded granted:', rewardType);
				if (window.Ads && typeof window.Ads.on_rewarded_ad_rewarded === 'function') {
					window.Ads.on_rewarded_ad_rewarded(rewardType);
				}
			},
			onClose: function(wasShown) {
				console.log('[YG Ads] Rewarded closed:', rewardType, wasShown);
				if (window.Ads && typeof window.Ads.on_rewarded_ad_closed === 'function') {
					window.Ads.on_rewarded_ad_closed(rewardType, !!wasShown);
				}
			},
			onError: function(error) {
				console.error('[YG Ads] Rewarded error:', rewardType, error);
				if (window.Ads && typeof window.Ads.on_rewarded_ad_failed === 'function') {
					window.Ads.on_rewarded_ad_failed(rewardType);
				}
			}
		}
	});
	return true;
})();
""" % escaped_reward_type
		var started = JavaScriptBridge.eval(js)
		if bool(started):
			return
		print("[Ads] Yandex rewarded unavailable, fallback success:", reward_type)

	call_deferred("_emit_rewarded_success", reward_type)

func show_interstitial_ad(trigger_id: String) -> void:
	if _interstitial_pending:
		print("[Ads] Interstitial already pending, ignore:", trigger_id)
		return
	_interstitial_pending = true
	_interstitial_trigger_id = trigger_id
	print("[Ads] Interstitial requested:", trigger_id)

	if _can_use_yandex_ads():
		var escaped_trigger_id := JSON.stringify(trigger_id)
		var js := """
(function() {
	if (typeof ysdk === 'undefined' || !ysdk.adv || !ysdk.adv.showFullscreenAdv) {
		return false;
	}
	var triggerId = %s;
	ysdk.adv.showFullscreenAdv({
		callbacks: {
			onOpen: function() {
				console.log('[YG Ads] Interstitial opened:', triggerId);
			},
			onClose: function(wasShown) {
				console.log('[YG Ads] Interstitial closed:', triggerId, wasShown);
				if (window.Ads && typeof window.Ads.on_interstitial_closed === 'function') {
					window.Ads.on_interstitial_closed(triggerId, !!wasShown);
				}
			},
			onError: function(error) {
				console.error('[YG Ads] Interstitial error:', triggerId, error);
				if (window.Ads && typeof window.Ads.on_interstitial_closed === 'function') {
					window.Ads.on_interstitial_closed(triggerId, false);
				}
			}
		}
	});
	return true;
})();
""" % escaped_trigger_id
		var started = JavaScriptBridge.eval(js)
		if bool(started):
			return
		print("[Ads] Yandex interstitial unavailable, fallback close:", trigger_id)

	call_deferred("_emit_interstitial_closed", trigger_id, false)

func _can_use_yandex_ads() -> bool:
	return OS.get_name() == "Web" and Engine.has_singleton("JavaScriptBridge") and Global.is_yandex_sdk_ready()

func _emit_rewarded_success(reward_type: String) -> void:
	_rewarded_pending = false
	_rewarded_type = ""
	_rewarded_was_rewarded = false
	rewarded_ad_completed.emit(reward_type)

func _emit_rewarded_failed(reward_type: String) -> void:
	_rewarded_pending = false
	_rewarded_type = ""
	_rewarded_was_rewarded = false
	rewarded_ad_failed.emit(reward_type)

func _emit_interstitial_closed(trigger_id: String, was_shown: bool) -> void:
	_interstitial_pending = false
	_interstitial_trigger_id = ""
	interstitial_closed.emit(trigger_id, was_shown)

# Вызывается из JavaScript Yandex SDK callbacks.onRewarded
func on_rewarded_ad_rewarded(reward_type: String) -> void:
	if not _rewarded_pending:
		return
	if reward_type != _rewarded_type:
		print("[Ads] Reward type mismatch:", reward_type, " expected:", _rewarded_type)
		return
	_rewarded_was_rewarded = true
	_emit_rewarded_success(reward_type)

# Вызывается из JavaScript Yandex SDK callbacks.onClose
func on_rewarded_ad_closed(reward_type: String = "", was_shown: bool = true) -> void:
	if not _rewarded_pending:
		return
	var final_type = reward_type if not reward_type.is_empty() else _rewarded_type
	if final_type != _rewarded_type:
		print("[Ads] Rewarded close type mismatch:", final_type, " expected:", _rewarded_type)
		return
	if _rewarded_was_rewarded:
		_rewarded_pending = false
		_rewarded_type = ""
		_rewarded_was_rewarded = false
		return
	_emit_rewarded_failed(final_type)

# Вызывается из JavaScript Yandex SDK callbacks.onError
func on_rewarded_ad_failed(reward_type: String = "") -> void:
	if not _rewarded_pending:
		return
	var final_type = reward_type if not reward_type.is_empty() else _rewarded_type
	if final_type.is_empty():
		return
	_emit_rewarded_failed(final_type)

# Вызывается из JavaScript Yandex SDK callbacks.onClose / callbacks.onError
func on_interstitial_closed(trigger_id: String = "", was_shown: bool = false) -> void:
	if not _interstitial_pending:
		return
	var final_id = trigger_id if not trigger_id.is_empty() else _interstitial_trigger_id
	if final_id.is_empty():
		return
	_emit_interstitial_closed(final_id, was_shown)
