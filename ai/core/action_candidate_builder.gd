extends RefCounted
class_name ActionCandidateBuilder

const MAX_CHOICE_COMBINATIONS := 64

static func expand(actions: Array) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var candidate_index := 0
	for action in actions:
		if not (action is Dictionary):
			continue
		var kind := str(action.get("kind", ""))
		if kind == "resolve_choice":
			var choice_payloads := build_choice_payloads(action)
			for choice_payload in choice_payloads:
				if choice_payload.is_empty():
					continue
				candidates.append(_build_candidate(action, choice_payload, _build_choice_target(action, choice_payload), candidate_index))
				candidate_index += 1
			continue
		var targets = action.get("targets", [])
		if targets is Array and not targets.is_empty():
			for target in targets:
				if not (target is Dictionary):
					continue
				var payload: Dictionary = action.get("payload_template", {}).duplicate(true)
				for key in target.keys():
					if key in ["defense_options"]:
						continue
					payload[key] = target.get(key)
				candidates.append(_build_candidate(action, payload, target, candidate_index))
				candidate_index += 1
			continue
		var target_mode := str(action.get("target_mode", "none"))
		if target_mode != "none":
			continue
		var payload: Dictionary = action.get("payload_template", {}).duplicate(true)
		candidates.append(_build_candidate(action, payload, {}, candidate_index))
		candidate_index += 1
	return _finalize_candidates(candidates)

static func build_choice_payloads(choice_action: Dictionary) -> Array[Dictionary]:
	var payload_template: Dictionary = choice_action.get("payload_template", {}).duplicate(true)
	var payloads: Array[Dictionary] = []
	var choice_type := str(choice_action.get("choice_type", choice_action.get("type", "")))
	if choice_type == "option_pick":
		var seen_option_ids: Dictionary = {}
		var options = choice_action.get("options", [])
		if options is Array and not options.is_empty():
			for option_value in options:
				if not (option_value is Dictionary):
					continue
				var option: Dictionary = option_value
				var option_id := str(option.get("id", "")).strip_edges()
				if option_id.is_empty() or seen_option_ids.has(option_id):
					continue
				seen_option_ids[option_id] = true
				var payload := payload_template.duplicate(true)
				payload["selected_option"] = option_id
				payloads.append(payload)
		return payloads
	var count: int = max(1, int(choice_action.get("count", 1)))
	var candidate_card_ids: Array[String] = []
	var seen_card_ids: Dictionary = {}
	for raw_card_id in choice_action.get("candidate_card_ids", []):
		var card_id := str(raw_card_id).strip_edges()
		if card_id.is_empty() or seen_card_ids.has(card_id):
			continue
		seen_card_ids[card_id] = true
		candidate_card_ids.append(card_id)
	if candidate_card_ids.is_empty():
		return payloads
	var selections := _build_card_selections(candidate_card_ids, count)
	var seen_payload_signatures: Dictionary = {}
	for selected in selections:
		if selected.is_empty():
			continue
		var payload := payload_template.duplicate(true)
		payload["selected_card_ids"] = selected.duplicate()
		var payload_signature := JSON.stringify(_normalize_payload_for_signature(payload))
		if seen_payload_signatures.has(payload_signature):
			continue
		seen_payload_signatures[payload_signature] = true
		payloads.append(payload)
	return payloads

static func _build_card_selections(candidate_card_ids: Array[String], count: int) -> Array[Array]:
	var selections: Array[Array] = []
	var safe_count: int = max(1, count)
	if candidate_card_ids.is_empty():
		return selections
	if safe_count >= candidate_card_ids.size():
		selections.append(candidate_card_ids.duplicate())
		return selections
	if safe_count == 1:
		for card_id in candidate_card_ids:
			selections.append([card_id])
		return selections
	var current: Array[String] = []
	_build_card_combinations(candidate_card_ids, safe_count, 0, current, selections, MAX_CHOICE_COMBINATIONS)
	if not selections.is_empty():
		return selections
	var fallback: Array[String] = []
	for card_id in candidate_card_ids:
		fallback.append(card_id)
		if fallback.size() >= safe_count:
			break
	if not fallback.is_empty():
		selections.append(fallback)
	return selections

static func _build_card_combinations(candidate_card_ids: Array[String], remaining: int, start_index: int, current: Array[String], selections: Array[Array], limit: int) -> void:
	if selections.size() >= limit:
		return
	if remaining <= 0:
		selections.append(current.duplicate())
		return
	var max_start := candidate_card_ids.size() - remaining
	for index in range(start_index, max_start + 1):
		current.append(candidate_card_ids[index])
		_build_card_combinations(candidate_card_ids, remaining - 1, index + 1, current, selections, limit)
		current.remove_at(current.size() - 1)
		if selections.size() >= limit:
			return

static func _build_candidate(action: Dictionary, payload: Dictionary, target, candidate_index: int) -> Dictionary:
	var safe_target: Dictionary = target.duplicate(true) if target is Dictionary else {}
	var kind := str(action.get("kind", ""))
	var command_type := str(action.get("command_type", ""))
	var proposal_id := str(action.get("proposal_id", ""))
	var choice_type := str(action.get("choice_type", action.get("type", "")))
	var source: Dictionary = action.get("source", {}).duplicate(true)
	var cost: Dictionary = action.get("cost", {}).duplicate(true)
	var morale_cost: int = int(cost.get("morale", 0))
	var discard_card_count: int = int(cost.get("discard_cards", 0))
	var hand_guard_card_count: int = _count_string_items(payload.get("master_guard_card_ids", []))
	var source_card_id := _resolve_source_card_id(action, payload)
	var target_card_id := _resolve_target_card_id(payload, safe_target)
	var target_player_id := _resolve_target_player_id(payload, safe_target)
	var target_summary := _build_target_summary(payload, safe_target)
	var enters_priority_window := _enters_priority_window(action)
	var enters_stack_resolution := _enters_stack_resolution(action)
	var changes_board_position := kind == "move_legion"
	var resolves_pending_choice := kind == "resolve_choice"
	var selection_count := _resolve_selection_count(action, payload)
	var selected_option_label := _resolve_selected_option_label(action, payload)
	var description := _build_description(action, payload, safe_target)
	var cost_summary := _build_cost_summary(action, payload, cost)
	var risk_summary := _build_risk_summary(action, payload, safe_target)
	var involved_card_ids := _collect_involved_card_ids(action, payload, safe_target)
	var tags := _build_tags(action, payload, safe_target)
	var action_group := _resolve_action_group(kind, command_type, choice_type)
	var action_group_label := _resolve_action_group_label(action_group)
	var group_order := _resolve_group_order(action_group)
	var candidate := {
		"candidate_id": _build_candidate_id(proposal_id, payload, candidate_index),
		"proposal_id": proposal_id,
		"kind": kind,
		"action": action,
		"command_type": command_type,
		"payload": payload.duplicate(true),
		"source": source,
		"target": safe_target,
		"source_card_id": source_card_id,
		"target_card_id": target_card_id,
		"target_player_id": target_player_id,
		"target_summary": target_summary,
		"ends_phase": kind == "end_phase",
		"passes_priority": kind == "pass_priority",
		"enters_priority_window": enters_priority_window,
		"enters_stack_resolution": enters_stack_resolution,
		"changes_board_position": changes_board_position,
		"resolves_pending_choice": resolves_pending_choice,
		"choice_type": choice_type,
		"selection_count": selection_count,
		"selected_option_label": selected_option_label,
		"morale_cost": morale_cost,
		"discard_card_count": discard_card_count,
		"hand_guard_card_count": hand_guard_card_count,
		"action_group": action_group,
		"action_group_label": action_group_label,
		"group_order": group_order,
		"description": description,
		"cost_summary": cost_summary,
		"risk_summary": risk_summary,
		"involved_card_ids": involved_card_ids,
		"tags": tags,
		"identity": {
			"candidate_id": _build_candidate_id(proposal_id, payload, candidate_index),
			"proposal_id": proposal_id,
			"kind": kind,
			"command_type": command_type
		},
		"source_target": {
			"source": source.duplicate(true),
			"target": safe_target.duplicate(true),
			"source_card_id": source_card_id,
			"target_card_id": target_card_id,
			"target_player_id": target_player_id,
			"target_summary": target_summary.duplicate(true)
		},
		"consequences": {
			"ends_phase": kind == "end_phase",
			"passes_priority": kind == "pass_priority",
			"enters_priority_window": enters_priority_window,
			"enters_stack_resolution": enters_stack_resolution,
			"changes_board_position": changes_board_position,
			"resolves_pending_choice": resolves_pending_choice,
			"choice_type": choice_type,
			"selection_count": selection_count,
			"selected_option_label": selected_option_label
		},
		"costs": {
			"morale_cost": morale_cost,
			"discard_card_count": discard_card_count,
			"hand_guard_card_count": hand_guard_card_count,
			"cost_summary": cost_summary
		},
		"summaries": {
			"description": description,
			"risk_summary": risk_summary,
			"involved_card_ids": involved_card_ids.duplicate(),
			"tags": tags.duplicate()
		},
		"presentation": {
			"action_group": action_group,
			"action_group_label": action_group_label,
			"group_order": group_order
		}
	}
	return candidate

static func _finalize_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var deduped: Array[Dictionary] = []
	var seen_signatures: Dictionary = {}
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if not _is_candidate_structurally_valid(candidate):
			continue
		var signature := _candidate_signature(candidate)
		if seen_signatures.has(signature):
			continue
		seen_signatures[signature] = true
		deduped.append(candidate.duplicate(true))
	_insertion_sort_candidates(deduped)
	return deduped

static func _is_candidate_structurally_valid(candidate: Dictionary) -> bool:
	if str(candidate.get("command_type", "")).strip_edges().is_empty():
		return false
	var payload = candidate.get("payload", {})
	return payload is Dictionary

static func _candidate_signature(candidate: Dictionary) -> String:
	var payload = candidate.get("payload", {})
	var normalized_payload := _normalize_payload_for_signature(payload if payload is Dictionary else {})
	return "%s|%s|%s" % [
		str(candidate.get("command_type", "")).strip_edges(),
		str(candidate.get("proposal_id", "")).strip_edges(),
		JSON.stringify(normalized_payload)
	]

static func _normalize_payload_for_signature(payload: Dictionary) -> Dictionary:
	var normalized: Dictionary = payload.duplicate(true)
	if normalized.has("selected_card_ids") and normalized.get("selected_card_ids", []) is Array:
		var selected_card_ids: Array[String] = []
		for raw_card_id in normalized.get("selected_card_ids", []):
			var card_id := str(raw_card_id).strip_edges()
			if card_id.is_empty() or selected_card_ids.has(card_id):
				continue
			selected_card_ids.append(card_id)
		selected_card_ids.sort()
		normalized["selected_card_ids"] = selected_card_ids
	return normalized

static func _insertion_sort_candidates(candidates: Array[Dictionary]) -> void:
	for i in range(1, candidates.size()):
		var current: Dictionary = candidates[i]
		var j := i - 1
		while j >= 0 and _candidate_should_sort_before(current, candidates[j]):
			candidates[j + 1] = candidates[j]
			j -= 1
		candidates[j + 1] = current

static func _candidate_should_sort_before(a: Dictionary, b: Dictionary) -> bool:
	var a_group := int(a.get("group_order", 999))
	var b_group := int(b.get("group_order", 999))
	if a_group != b_group:
		return a_group < b_group
	var a_cost := int(a.get("morale_cost", 0))
	var b_cost := int(b.get("morale_cost", 0))
	if a_cost != b_cost:
		return a_cost < b_cost
	var a_selection := int(a.get("selection_count", 0))
	var b_selection := int(b.get("selection_count", 0))
	if a_selection != b_selection:
		return a_selection < b_selection
	return str(a.get("candidate_id", "")) < str(b.get("candidate_id", ""))

static func _resolve_action_group(kind: String, command_type: String, choice_type: String) -> String:
	if kind == "resolve_choice" or command_type == "ResolveChoice":
		return "choice"
	if kind == "choose_defense" or command_type == "ChooseDefense":
		return "defense"
	if kind == "activate_effect" or command_type == "ActivateEffect":
		return "effect"
	if kind == "play_card" or command_type == "PlayCard":
		return "play"
	if kind == "move_legion" or command_type == "MoveLegion":
		return "positioning"
	if kind == "declare_attack" or command_type == "DeclareAttack":
		return "attack"
	if kind == "pass_priority" or command_type == "PassPriority":
		return "priority"
	if kind == "end_phase" or command_type == "EndPhase":
		return "phase"
	if not choice_type.is_empty():
		return "choice"
	return "other"

static func _resolve_action_group_label(action_group: String) -> String:
	match action_group:
		"choice":
			return "处理选择"
		"defense":
			return "防守响应"
		"effect":
			return "发动效果"
		"play":
			return "出牌"
		"positioning":
			return "站位调整"
		"attack":
			return "进攻"
		"priority":
			return "优先权"
		"phase":
			return "阶段推进"
		_:
			return "其他动作"

static func _resolve_group_order(action_group: String) -> int:
	match action_group:
		"choice":
			return 0
		"defense":
			return 1
		"effect":
			return 2
		"play":
			return 3
		"positioning":
			return 4
		"attack":
			return 5
		"priority":
			return 6
		"phase":
			return 7
		_:
			return 8

static func _build_choice_target(action: Dictionary, payload: Dictionary) -> Dictionary:
	var choice_target := {
		"choice_type": str(action.get("choice_type", action.get("type", "")))
	}
	if payload.has("selected_option"):
		choice_target["selected_option"] = str(payload.get("selected_option", ""))
	if payload.has("selected_card_ids"):
		choice_target["selected_card_ids"] = payload.get("selected_card_ids", []).duplicate(true)
	return choice_target

static func _resolve_source_card_id(action: Dictionary, payload: Dictionary) -> String:
	var source: Dictionary = action.get("source", {})
	for key in ["card_id", "source_id"]:
		var candidate_id := str(source.get(key, payload.get(key, ""))).strip_edges()
		if not candidate_id.is_empty():
			return candidate_id
	return ""

static func _resolve_target_card_id(payload: Dictionary, target: Dictionary) -> String:
	for key in ["defender_id", "target_card_id", "blocker_id", "supporter_id", "card_id"]:
		var candidate_id := str(target.get(key, payload.get(key, ""))).strip_edges()
		if not candidate_id.is_empty():
			return candidate_id
	return ""

static func _resolve_target_player_id(payload: Dictionary, target: Dictionary) -> int:
	for key in ["target_player", "target_player_id", "player_id"]:
		var value = target.get(key, payload.get(key, null))
		if value is int:
			return int(value)
		if value is float:
			return int(value)
		if value is String and str(value).is_valid_int():
			return int(value)
	return -1

static func _build_target_summary(payload: Dictionary, target: Dictionary) -> Dictionary:
	var summary := {
		"target_kind": str(target.get("target_kind", payload.get("target_kind", ""))),
		"target_card_id": _resolve_target_card_id(payload, target),
		"target_player_id": _resolve_target_player_id(payload, target),
		"row": str(target.get("row", payload.get("row", ""))),
		"col": int(target.get("col", payload.get("col", -1))),
		"selected_option": str(target.get("selected_option", payload.get("selected_option", ""))),
		"selected_card_ids": payload.get("selected_card_ids", []).duplicate(true)
	}
	return summary

static func _resolve_selection_count(action: Dictionary, payload: Dictionary) -> int:
	if payload.has("selected_card_ids"):
		var selected_card_ids = payload.get("selected_card_ids", [])
		if selected_card_ids is Array:
			return (selected_card_ids as Array).size()
	if payload.has("selected_option"):
		return 1
	var choice_type := str(action.get("choice_type", action.get("type", "")))
	if not choice_type.is_empty():
		return max(1, int(action.get("count", 1)))
	return 0

static func _resolve_selected_option_label(action: Dictionary, payload: Dictionary) -> String:
	var selected_option := str(payload.get("selected_option", "")).strip_edges()
	if selected_option.is_empty():
		return ""
	var options = action.get("options", [])
	if not (options is Array):
		return ""
	for option_value in options:
		if not (option_value is Dictionary):
			continue
		var option: Dictionary = option_value
		if str(option.get("id", "")).strip_edges() != selected_option:
			continue
		return str(option.get("label", option.get("title", selected_option)))
	return ""

static func _enters_priority_window(action: Dictionary) -> bool:
	var kind := str(action.get("kind", ""))
	var play_kind := str(action.get("play_kind", ""))
	if kind == "activate_effect":
		return true
	if kind == "declare_attack":
		return true
	if kind == "pass_priority":
		return true
	if kind == "play_card":
		return play_kind == "tactic" or play_kind == "counter_tactic" or play_kind == "hand_response"
	return false

static func _enters_stack_resolution(action: Dictionary) -> bool:
	var kind := str(action.get("kind", ""))
	var play_kind := str(action.get("play_kind", ""))
	if kind == "activate_effect":
		return true
	if kind == "play_card":
		return play_kind == "tactic" or play_kind == "counter_tactic" or play_kind == "hand_response"
	return false

static func _count_string_items(value) -> int:
	if not (value is Array):
		return 0
	var count := 0
	for item in value:
		if not str(item).strip_edges().is_empty():
			count += 1
	return count

static func _build_candidate_id(proposal_id: String, payload: Dictionary, candidate_index: int) -> String:
	var payload_text: String = JSON.stringify(payload)
	var payload_hash: int = abs(payload_text.hash())
	var safe_proposal_id: String = _sanitize_token(proposal_id if not proposal_id.is_empty() else "proposal")
	return "cand_%03d_%s_%s" % [candidate_index, safe_proposal_id, str(payload_hash)]

static func _sanitize_token(text: String) -> String:
	var result := text.to_lower()
	for symbol in [":", ",", " ", "-", "/", "\\", "{", "}", "[", "]", "(", ")", "\"", "'"]:
		result = result.replace(symbol, "_")
	while result.find("__") != -1:
		result = result.replace("__", "_")
	return result.strip_edges().trim_prefix("_").trim_suffix("_")

static func _build_description(action: Dictionary, payload: Dictionary, target: Dictionary) -> String:
	var base := str(action.get("label", str(action.get("kind", "action"))))
	var target_text := _describe_target(payload, target)
	if target_text.is_empty():
		return base
	return "%s -> %s" % [base, target_text]

static func _describe_target(payload: Dictionary, target: Dictionary) -> String:
	if not target.is_empty():
		var target_kind := str(target.get("target_kind", ""))
		if target_kind == "master":
			return "目标: 对方主将"
		if target.has("row") or target.has("col"):
			var row_text := _row_text(str(target.get("row", payload.get("row", ""))))
			var col := int(target.get("col", payload.get("col", -1)))
			if not row_text.is_empty() and col >= 0:
				return "位置: %s %d 号位" % [row_text, col + 1]
			if not row_text.is_empty():
				return "位置: %s" % row_text
		var defender_id := str(target.get("defender_id", target.get("target_card_id", "")))
		if not defender_id.is_empty():
			return "目标卡: %s" % defender_id
		if target.has("selected_option"):
			return "选项: %s" % str(target.get("selected_option", ""))
	if payload.has("selected_option"):
		return "选项: %s" % str(payload.get("selected_option", ""))
	if payload.has("master_guard_card_ids"):
		return "目标: 主将守卫"
	return ""

static func _row_text(row: String) -> String:
	match row:
		"front":
			return "前排"
		"back":
			return "后排"
		"artifact":
			return "神器区"
		"artifact_zone":
			return "神器区"
		"tactic":
			return "战术区"
		"hand_response":
			return "响应区"
		_:
			return row

static func _build_cost_summary(action: Dictionary, payload: Dictionary, cost: Dictionary) -> String:
	var parts: Array[String] = []
	if not cost.is_empty():
		if cost.has("morale"):
			parts.append("消耗 %d 士气" % int(cost.get("morale", 0)))
		if cost.has("discard_cards"):
			parts.append("弃置 %d 张牌" % int(cost.get("discard_cards", 0)))
	if payload.has("master_guard_card_ids"):
		var guard_count: int = payload.get("master_guard_card_ids", []).size()
		if guard_count > 0:
			parts.append("使用 %d 张手牌守卫主将" % guard_count)
	if parts.is_empty():
		return "未记录显式额外费用"
	return "，".join(parts)

static func _build_risk_summary(action: Dictionary, payload: Dictionary, target: Dictionary) -> String:
	var kind := str(action.get("kind", ""))
	var play_kind := str(action.get("play_kind", ""))
	if kind == "declare_attack":
		if str(target.get("target_kind", payload.get("target_kind", "card"))) == "master":
			return "会进入进攻响应窗口，并直接对主将施压"
		return "会进入进攻响应窗口，可能发生防守或交换"
	if kind == "move_legion":
		return "会改变站位，实际是否保留行动窗口由规则引擎结算"
	if kind == "play_card":
		if play_kind == "tactic" or play_kind == "counter_tactic" or play_kind == "hand_response":
			return "会进入优先权或堆叠结算窗口"
		return "会改变场面公开资源，执行前仍需本地校验"
	if kind == "activate_effect":
		return "可能进入优先权或堆叠结算窗口"
	if kind == "choose_defense":
		return "用于当前攻击响应窗口"
	if kind == "pass_priority":
		return "会让出当前优先权"
	if kind == "end_phase":
		return "会结束当前阶段并放弃本阶段剩余行动"
	if kind == "resolve_choice":
		return "会推进当前待处理选择并可能触发后续结算"
	return "执行前仍需通过本地校验"

static func _collect_involved_card_ids(action: Dictionary, payload: Dictionary, target: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	_append_card_id_if_present(ids, str(action.get("source", {}).get("card_id", "")))
	_append_card_id_if_present(ids, str(action.get("source", {}).get("source_id", "")))
	for key in ["card_id", "source_id", "attacker_id", "defender_id", "target_card_id", "blocker_id", "supporter_id"]:
		_append_card_id_if_present(ids, str(payload.get(key, "")))
		_append_card_id_if_present(ids, str(target.get(key, "")))
	for raw_id in payload.get("master_guard_card_ids", []):
		_append_card_id_if_present(ids, str(raw_id))
	for raw_id in payload.get("selected_card_ids", []):
		_append_card_id_if_present(ids, str(raw_id))
	return ids

static func _append_card_id_if_present(ids: Array[String], card_id: String) -> void:
	if card_id.is_empty() or ids.has(card_id):
		return
	ids.append(card_id)

static func _build_tags(action: Dictionary, payload: Dictionary, target: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	_append_tag(tags, str(action.get("kind", "")))
	_append_tag(tags, str(action.get("play_kind", "")))
	_append_tag(tags, str(action.get("target_mode", "")))
	_append_tag(tags, str(action.get("choice_type", action.get("type", ""))))
	_append_tag(tags, str(target.get("target_kind", payload.get("target_kind", ""))))
	_append_tag(tags, str(action.get("source", {}).get("defense_kind", "")))
	if payload.has("master_guard_card_ids"):
		_append_tag(tags, "master_guard")
	var cost: Dictionary = action.get("cost", {})
	if cost.has("morale"):
		_append_tag(tags, "cost_morale")
	if cost.has("discard_cards"):
		_append_tag(tags, "cost_discard")
	return tags

static func _append_tag(tags: Array[String], tag: String) -> void:
	if tag.is_empty() or tag == "none" or tags.has(tag):
		return
	tags.append(tag)
