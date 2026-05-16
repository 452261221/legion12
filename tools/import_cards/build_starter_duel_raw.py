from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

RAW_DIR = ROOT / "data" / "raw_rule_cards"
CARD_OUTPUT = ROOT / "data" / "cards" / "starter_duel_raw_cards.json"
DECK_OUTPUT = ROOT / "data" / "decks" / "starter_takamagahara_asgard_raw.json"
MASTER_OUTPUT = ROOT / "data" / "raw_rule_cards" / "starter_duel_master_cards.json"
MANIFEST_FILES = ["manifest_2.json", "manifest_4.json", "manifest_8.json"]

FACTION_BY_PDF = {
    "2.pdf": "asgard",
    "4.pdf": "takamagahara",
    "8.pdf": "neutral",
}

TACTIC_COUNTER_MARKERS = {"反击", "战术反击"}
NOISE_EXACT = {
    "高天原",
    "阿斯加德",
    "通用",
    "军团",
    "军团卡",
    "战术",
    "战术卡",
    "战术主动",
    "战术反击",
    "圣物",
    "圣物卡",
    "主宰卡",
    "主宰者",
    "LEGION CARD",
    "LEGIONCARD",
    "LEGIONGARD",
    "TACTIC CARD",
    "TACTICCARD",
    "ARTIFACT CARD",
    "MASTER CARD",
    "DIVINITY CARD",
    "COST CARD",
    "SAMPLE",
    "SAMP",
    "SAM",
    "SAMRLE",
    "AMPLE",
    "AMP",
    "AMR",
    "RE",
    "LE",
    "GAMES",
    "兵力",
    "血量",
    "天灾等级",
    "天灾等级:",
    "天灾等级：",
}
CODE_RE = re.compile(r"S\d{2}-[0-9A-Z]+", re.IGNORECASE)
URL_RE = re.compile(r"https?://", re.IGNORECASE)
PAGE_RE = re.compile(r"^\d+/\d+$")
TIME_RE = re.compile(r"^\d{4}/\d+/\d+")
NUM_RE = re.compile(r"^\d{3,5}$")
POWER_RE = re.compile(r"(\d{4})")
POWER_OVERRIDES = {
    "S01-0001": 6000,
}
COST_OVERRIDES = {
    "S01-0001": 7,
    "S01-0002": 4,
    "S01-0015": 0,
    "S01-0016": 2,
    "S01-0303": 6,
    "S01-0304": 6,
    "S01-0305": 5,
    "S01-0306": 5,
    "S01-0307": 5,
    "S01-0308": 5,
    "S01-0311": 4,
    "S01-0312": 3,
    "S01-0316": 2,
    "S01-0318": 3,
    "S01-0319": 3,
    "S01-0401": 8,
    "S01-0404": 5,
    "S01-0405": 5,
    "S01-0409": 4,
    "S01-0410": 3,
    "S01-0413": 3,
    "S01-0414": 3,
    "S01-0415": 2,
    "S01-0416": 1,
    "S01-0417": 3,
    "S01-0418": 4,
    "S01-0419": 1,
}
MASTER_HP_OVERRIDES = {
    "洛基": 12,
    "须佐之男": 9,
}
CALAMITY_LEVEL_OVERRIDES = {
    "S01-0303": 1,
    "S01-0304": 2,
    "S01-0305": 1,
    "S01-0306": 1,
    "S01-0307": 1,
    "S01-0308": 1,
}
IMPLEMENTED_CARD_PATCHES = {
    "S01-0001": {
        "status": "tested",
        "effects": [
            {
                "id": "teach_enters_loot",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "登场时双方各弃置1张手牌。随后，我方抽2张牌，对方抽1张牌。",
                "resolution": {
                    "action": "both_players_discard_then_draw",
                    "controller_discard": 1,
                    "opponent_discard": 1,
                    "controller_draw": 2,
                    "opponent_draw": 1,
                },
            },
            {
                "id": "teach_falls_refills",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "阵亡时可抽取2张牌，并弃置1张手牌。",
                "resolution": {
                    "action": "master_draw_then_discard",
                    "draw_count": 2,
                    "discard_count": 1,
                },
            },
        ],
    },
    "S01-0002": {
        "status": "tested",
        "effects": [
            {
                "id": "mercenary_reposition",
                "kind": "activated",
                "text": "我方回合1次，可进行1次位移。",
                "once_per_turn_key": "mercenary_reposition",
                "resolution": {
                    "action": "move_source_one_step",
                },
            },
            {
                "id": "mercenary_hand_guard",
                "kind": "activated",
                "hand_response": True,
                "hidden_from_actions": True,
                "text": "对方进攻我方军团时，可从手牌中弃置此军团：抵挡本次进攻。",
                "resolution": {
                    "action": "counter_pending_attack",
                },
            },
        ],
    },
    "S01-0015": {
        "status": "tested",
        "effects": [
            {
                "id": "truce_offer",
                "kind": "activated",
                "text": "抽1张牌，然后由对手决定双方是否各抽1张牌",
                "resolution": {"action": "offer_truce_draw"},
            }
        ],
    },
    "S01-0016": {
        "status": "tested",
        "effects": [
            {
                "id": "absolute_defense",
                "kind": "activated",
                "text": "弃1张手牌：抵挡本次进攻或无效该效果",
                "cost": {"discard_cards": 1},
                "resolution": {"action": "counter_target_stack"},
            }
        ],
    },
    "S01-0319": {
        "status": "tested",
        "effects": [
            {
                "id": "hunt_execute",
                "kind": "activated",
                "text": "击杀对方1张兵力不高于6000的军团",
                "target_mode": "card",
                "additional_stack_effect_ids": ["hunt_recycle"],
                "resolution": {
                    "action": "destroy_target_unit",
                    "target_scope": "enemy_battlefield",
                    "type": "legion",
                    "max_target_power": 6000,
                },
            },
            {
                "id": "hunt_recycle",
                "kind": "triggered",
                "hidden_from_actions": True,
                "text": "将墓地4张牌返回牌库底部",
                "resolution": {"action": "recycle_grave_to_deck", "count": 4},
            },
        ],
    },
    "S01-0312": {
        "status": "tested",
        "effects": [
            {
                "id": "lagertha_front_guard",
                "kind": "continuous",
                "text": "位于前排时获得挑衅，且在对方回合兵力+1000",
                "resolution": {
                    "action": "modify_power",
                    "target_scope": "self",
                    "required_row": "front",
                    "only_during_opponent_turn": True,
                    "amount": 1000,
                },
            }
        ],
    },
    "S01-0303": {
        "status": "tested",
        "keywords": [],
        "play_options": [
            {
                "id": "ragnar_blood_price",
                "label": "对我方主宰造成1点伤害：此军团登场费用-1",
                "self_master_damage": 1,
                "play_cost_modifier": -1,
            }
        ],
        "effects": [
            {
                "id": "ragnar_desperate_charge",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "若我方主宰血量不高于7，获得冲锋",
                "condition": {
                    "own_master_hp_at_most": 7,
                },
                "resolution": {
                    "action": "grant_source_keyword_until_turn_end",
                    "keyword": "charge",
                },
            },
            {
                "id": "ragnar_last_roar",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "阵亡时可抽取1张牌，并弃置1张手牌",
                "resolution": {
                    "action": "master_draw_then_discard",
                    "draw_count": 1,
                    "discard_count": 1,
                },
            },
        ],
    },
    "S01-0304": {
        "status": "tested",
        "keywords": [],
        "play_options": [
            {
                "id": "harald_blood_price",
                "label": "对我方主宰造成1点伤害：此军团登场费用-1",
                "self_master_damage": 1,
                "play_cost_modifier": -1,
            }
        ],
        "effects": [
            {
                "id": "harald_ruthless_entry",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "登场时，若对方主宰血量高于我方，可对其造成1点伤害",
                "condition": {
                    "controller_master_hp_less_than_opponent": True,
                },
                "resolution": {
                    "action": "deal_master_damage",
                    "player_scope": "opponent",
                    "amount": 1,
                },
            },
            {
                "id": "harald_last_strike",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "阵亡时击杀对方1张兵力不高于2000的军团",
                "resolution": {
                    "action": "choose_and_destroy_unit",
                    "target_scope": "enemy_battlefield",
                    "type": "legion",
                    "max_target_power": 2000,
                },
            },
        ],
    },
    "S01-0305": {
        "status": "tested",
        "effects": [
            {
                "id": "bjorn_low_hp_discount",
                "kind": "continuous",
                "text": "若我方主宰血量不高于6，此军团登场费用-1",
                "resolution": {
                    "action": "modify_play_cost",
                    "amount": -1,
                    "own_master_hp_at_most": 6,
                },
            },
            {
                "id": "bjorn_falls_and_returns",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "阵亡时可对我方主宰造成1点伤害，并将墓地4张卡牌返回牌库底部：此军团可重新休整登场",
                "resolution": {
                    "action": "deal_master_damage",
                    "amount": 1,
                    "follow_up_action": {
                        "action": "recycle_grave_to_deck",
                        "count": 4,
                        "require_exact_count": True,
                        "follow_up_action": {
                            "action": "revive_source_from_grave",
                        },
                    },
                },
            },
        ],
    },
    "S01-0308": {
        "status": "tested",
        "play_options": [
            {
                "id": "erik_blood_price",
                "label": "对我方主宰造成1点伤害：此军团登场费用-1",
                "self_master_damage": 1,
                "play_cost_modifier": -1,
            }
        ],
        "effects": [
            {
                "id": "erik_master_hit_discard",
                "kind": "triggered",
                "event": "MasterDamaged",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "此军团对主宰造成伤害时：对方弃置1张手牌",
                "condition": {
                    "source_kind_is": "attack",
                },
                "resolution": {
                    "action": "discard_cards",
                    "player_scope": "event_player",
                    "count": 1,
                },
            },
            {
                "id": "erik_falls_revives_raider",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "阵亡时将墓地1张费用不高于3的【阿斯加德】军团活跃登场",
                "resolution": {
                    "action": "revive_from_grave",
                    "count": 1,
                    "type": "legion",
                    "faction": "asgard",
                    "max_target_cost": 3,
                },
            },
        ],
    },
    "S01-0307": {
        "status": "tested",
        "effects": [
            {
                "id": "alvilda_blood_summon",
                "kind": "activated",
                "text": "我方回合可弃置此军团：对我方主宰造成1点伤害，将手牌中1张天灾等级2的军团活跃登场",
                "resolution": {
                    "action": "sacrifice_source_and_deploy_from_hand",
                    "self_master_damage": 1,
                    "type": "legion",
                    "calamity_level": 2,
                },
            },
            {
                "id": "alvilda_falls_salvages_card",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "阵亡时将墓地1张费用不高于3的【阿斯加德】卡牌加入手牌",
                "resolution": {
                    "action": "return_from_grave_to_hand",
                    "count": 1,
                    "faction": "asgard",
                    "max_target_cost": 3,
                },
            },
        ],
    },
    "S01-0316": {
        "status": "tested",
        "effects": [
            {
                "id": "egil_blood_verse",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "登场时可对我方主宰造成1点伤害，弃置我方牌库顶部2张牌：选择对方1张军团，本回合兵力-2000",
                "resolution": {
                    "action": "deal_master_damage",
                    "amount": 1,
                    "follow_up_action": {
                        "action": "mill_cards",
                        "count": 2,
                        "follow_up_action": {
                            "action": "choose_and_modify_power_until_turn_end",
                            "target_scope": "enemy_battlefield",
                            "type": "legion",
                            "amount": -2000,
                        },
                    },
                },
            }
        ],
    },
    "S01-0318": {
        "status": "tested",
        "effects": [
            {
                "id": "valkyrie_call",
                "kind": "activated",
                "text": "可对我方主宰造成1点伤害：选择墓地1张费用不高于5的阿斯加德军团活跃登场；若我方主宰血量不高于5，则其血量不会因此效果而减少",
                "resolution": {
                    "action": "deal_master_damage",
                    "amount": 1,
                    "waive_if_own_master_hp_at_most": 5,
                    "follow_up_action": {
                        "action": "revive_from_grave",
                        "count": 1,
                        "faction": "asgard",
                        "type": "legion",
                        "max_target_cost": 5,
                    },
                },
            }
        ],
    },
    "S01-0311": {
        "status": "tested",
        "effects": [
            {
                "id": "gustav_attack_rally",
                "kind": "triggered",
                "event": "AttackDeclared",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "进攻时可将墓地2张卡牌返回牌库底部：此军团本回合兵力+2000",
                "resolution": {
                    "action": "recycle_grave_to_deck",
                    "count": 2,
                    "require_exact_count": True,
                    "follow_up_action": {
                        "action": "modify_source_power_until_turn_end",
                        "amount": 2000,
                    },
                },
            },
            {
                "id": "gustav_second_wind",
                "kind": "triggered",
                "event": "AttackFinished",
                "self_only": True,
                "hidden_from_actions": True,
                "once_per_turn_key": "gustav_second_wind",
                "text": "回合1次，此军团进攻后可将墓地2张卡牌返回牌库底部：将此军团转为活跃",
                "resolution": {
                    "action": "recycle_grave_to_deck",
                    "count": 2,
                    "require_exact_count": True,
                    "follow_up_action": {
                        "action": "ready_source_card",
                    },
                },
            },
        ],
    },
    "S01-0306": {
        "status": "tested",
        "effects": [
            {
                "id": "olaf_low_hp_discount",
                "kind": "continuous",
                "text": "若我方主宰血量不高于6，此军团登场费用-1",
                "resolution": {
                    "action": "modify_play_cost",
                    "amount": -1,
                    "own_master_hp_at_most": 6,
                },
            },
            {
                "id": "olaf_attack_raid",
                "kind": "triggered",
                "event": "AttackDeclared",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "进攻时可将墓地1张卡牌置入我方牌库底部：此军团本回合获得强攻",
                "resolution": {
                    "action": "recycle_grave_to_deck",
                    "count": 1,
                    "follow_up_action": {
                        "action": "grant_master_damage_bonus",
                        "target_scope": "self",
                        "amount": 1,
                    },
                },
            },
            {
                "id": "olaf_last_stand",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "阵亡时可抽取2张牌，并弃置1张手牌",
                "resolution": {
                    "action": "master_draw_then_discard",
                    "draw_count": 2,
                    "discard_count": 1,
                },
            },
        ],
    },
    "S01-0401": {
        "status": "tested",
        "effects": [
            {
                "id": "honda_crush_costs",
                "kind": "triggered",
                "event": "AttackDeclared",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "进攻时：对方所有军团本回合费用-1。随后击杀对方1张费用为0的军团",
                "resolution": {
                    "action": "modify_matching_cost",
                    "target_scope": "enemy_battlefield",
                    "type": "legion",
                    "amount": -1,
                    "follow_up_action": {
                        "action": "choose_and_destroy_unit",
                        "target_scope": "enemy_battlefield",
                        "type": "legion",
                        "max_target_cost": 0,
                    },
                },
            }
        ],
    },
    "S01-0404": {
        "status": "tested",
    },
    "S01-0405": {
        "status": "tested",
        "keywords": [],
        "effects": [
            {
                "id": "musashi_lone_charge",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "登场时，若我方前排没有其他军团，此军团获得冲锋",
                "condition": {
                    "allied_front_other_count_at_most": 0,
                },
                "resolution": {
                    "action": "grant_source_keyword_until_turn_end",
                    "keyword": "charge",
                },
            },
            {
                "id": "musashi_attack_draw",
                "kind": "triggered",
                "event": "AttackDeclared",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "进攻时，若我方手牌数量不高于对方，可抽取1张牌",
                "condition": {
                    "controller_hand_size_at_most_opponent": True,
                },
                "resolution": {
                    "action": "draw_cards",
                    "count": 1,
                },
            },
        ],
    },
    "S01-0409": {
        "status": "tested",
        "keywords": [],
        "effects": [
            {
                "id": "yoshitsune_backline_power_shift",
                "kind": "continuous",
                "text": "位于后排时，此军团兵力视为2000",
                "resolution": {
                    "action": "modify_power",
                    "target_scope": "self",
                    "required_row": "back",
                    "amount": -2000,
                },
            },
            {
                "id": "yoshitsune_backline_ranged",
                "kind": "continuous",
                "text": "位于后排时，进攻距离+1，远程进攻无损",
                "resolution": {
                    "action": "grant_keyword",
                    "target_scope": "self",
                    "required_row": "back",
                    "keyword": "ranged",
                },
            },
            {
                "id": "yoshitsune_backline_safe_shot",
                "kind": "continuous",
                "text": "位于后排时，进攻距离+1，远程进攻无损",
                "resolution": {
                    "action": "grant_keyword",
                    "target_scope": "self",
                    "required_row": "back",
                    "keyword": "attack_no_loss",
                },
            },
            {
                "id": "yoshitsune_reposition",
                "kind": "activated",
                "text": "我方回合1次，可进行1次位移",
                "once_per_turn_key": "yoshitsune_reposition",
                "resolution": {
                    "action": "move_source_one_step",
                },
            },
            {
                "id": "yoshitsune_kill_draw",
                "kind": "triggered",
                "event": "CardDied",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "击杀时可抽取3张牌",
                "condition": {
                    "source_kind_is": "attack",
                    "source_card_id_is_self": True,
                },
                "resolution": {
                    "action": "draw_cards",
                    "count": 3,
                },
            },
        ],
    },
    "S01-0410": {
        "status": "tested",
    },
    "S01-0413": {
        "status": "tested",
        "effects": [
            {
                "id": "hiromasa_enter_draw",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "登场时，若我方手牌不高于5张，可抽取1张牌",
                "condition": {
                    "own_hand_size_at_most": 5,
                },
                "resolution": {
                    "action": "draw_cards",
                    "count": 1,
                },
            },
            {
                "id": "hiromasa_attack_silence_counter",
                "kind": "triggered",
                "event": "AttackDeclared",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "进攻时：选择对方1张反击战术，本回合无法发动",
                "resolution": {
                    "action": "disable_enemy_hand_counter_tactic_until_turn_end",
                },
            },
        ],
    },
    "S01-0414": {
        "status": "tested",
        "effects": [
            {
                "id": "kogoro_tactical_withdrawal",
                "kind": "triggered",
                "event": "AttackFinished",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "此军团进攻后，可返回牌库顶部。此军团返回牌库顶部时：将我方最多2张士气转为活跃",
                "resolution": {
                    "action": "return_source_to_deck_top",
                    "follow_up_action": {
                        "action": "ready_spent_morale",
                        "count": 2,
                    },
                },
            }
        ],
    },
    "S01-0415": {
        "status": "tested",
        "keywords": [],
        "effects": [
            {
                "id": "hanzo_frontline_ranged",
                "kind": "continuous",
                "text": "位于前排时，进攻距离+1，远程进攻无损。",
                "resolution": {
                    "action": "grant_keyword",
                    "target_scope": "self",
                    "required_row": "front",
                    "keyword": "ranged",
                },
            },
            {
                "id": "hanzo_frontline_safe_shot",
                "kind": "continuous",
                "text": "位于前排时，进攻距离+1，远程进攻无损。",
                "resolution": {
                    "action": "grant_keyword",
                    "target_scope": "self",
                    "required_row": "front",
                    "keyword": "attack_no_loss",
                },
            },
            {
                "id": "hanzo_conceal_on_play",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "登场时，发动隐匿。",
                "resolution": {
                    "action": "conceal_source",
                },
            },
            {
                "id": "hanzo_reveal",
                "kind": "activated",
                "text": "主动翻回正面",
                "target_mode": "none",
                "resolution": {
                    "action": "reveal_source_face_up",
                },
            },
        ],
    },
    "S01-0416": {
        "status": "tested",
        "effects": [
            {
                "id": "komatsu_supporting_shot",
                "kind": "triggered",
                "event": "AttackDeclared",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "进攻时：选择我方前排1张稻姬本多小松以外兵力不高于5000的高天原军团，本回合兵力+1000",
                "resolution": {
                    "action": "choose_and_modify_power_until_turn_end",
                    "target_scope": "allied_battlefield",
                    "exclude_self": True,
                    "required_row": "front",
                    "faction": "takamagahara",
                    "type": "legion",
                    "max_target_power": 5000,
                    "amount": 1000,
                },
            }
        ],
    },
    "S01-0417": {
        "status": "tested",
        "effects": [
            {
                "id": "kusanagi_enter_destroy",
                "kind": "triggered",
                "event": "CardPlayed",
                "self_only": True,
                "hidden_from_actions": True,
                "text": "登场时：击杀对方1张费用不高于2的军团",
                "resolution": {
                    "action": "choose_and_destroy_unit",
                    "target_scope": "enemy_battlefield",
                    "type": "legion",
                    "max_target_cost": 2,
                },
            },
            {
                "id": "kusanagi_weaken",
                "kind": "activated",
                "text": "选择对方1张军团，本回合费用-1",
                "target_mode": "card",
                "cost": {"morale": 1},
                "resolution": {
                    "action": "modify_target_cost",
                    "target_scope": "enemy_battlefield",
                    "type": "legion",
                    "amount": -1,
                },
            },
            {
                "id": "kusanagi_assault",
                "kind": "activated",
                "text": "选择我方1张高天原军团，本回合获得强攻",
                "target_mode": "card",
                "cost": {"morale": 1},
                "resolution": {
                    "action": "grant_master_damage_bonus",
                    "target_scope": "allied_battlefield",
                    "type": "legion",
                    "faction": "takamagahara",
                    "amount": 1,
                },
            },
        ],
    },
    "S01-0419": {
        "status": "tested",
        "effects": [
            {
                "id": "oiran_search",
                "kind": "activated",
                "text": "查看牌库顶部3张牌，选择其中1张高天原卡加入手牌，其余返回牌库底部",
                "resolution": {
                    "action": "search_deck",
                    "max_look": 3,
                    "count": 1,
                    "match": {
                        "faction": "takamagahara",
                        "exclude_definition_id": "takamagahara_s01_0419",
                    },
                    "follow_up_action": {
                        "action": "ready_spent_morale",
                        "count": 1,
                    },
                },
            }
        ],
    },
    "S01-0418": {
        "status": "tested",
        "effects": [
            {
                "id": "tenchu",
                "kind": "activated",
                "text": "击杀对方1张费用不高于7的军团",
                "target_mode": "card",
                "resolution": {
                    "action": "destroy_target_unit",
                    "target_scope": "enemy_battlefield",
                    "type": "legion",
                    "max_target_cost": 7,
                },
            }
        ],
    },
}
POWER_CROP_BOX = (300, 1160, 960, 1405)


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def clean_line(text: str) -> str:
    return (
        str(text)
        .strip()
        .replace("（", "(")
        .replace("）", ")")
        .replace("『", "")
        .replace("』", "")
    )


def slug_card_code(row: dict) -> str:
    for line in row.get("ocr_lines", []):
        match = CODE_RE.search(str(line))
        if match:
            return match.group(0)
    return f"{row['pdf']}_{row['page']}"


def normalize_card_type(row: dict) -> str:
    if row["card_type"] != "tactic":
        return row["card_type"]
    cleaned_lines = {clean_line(line) for line in row.get("ocr_lines", [])}
    if cleaned_lines.intersection(TACTIC_COUNTER_MARKERS):
        return "counter_tactic"
    return "tactic"


def is_noise_line(line: str) -> bool:
    upper = line.upper()
    if not line:
        return True
    if line in NOISE_EXACT or upper in NOISE_EXACT:
        return True
    if URL_RE.search(line) or PAGE_RE.match(line) or TIME_RE.match(line) or CODE_RE.search(line):
        return True
    if NUM_RE.match(line):
        return True
    if "服务号" in line or "CYNIC" in upper:
        return True
    if line.endswith("阵营"):
        return True
    return False


def extract_text(row: dict) -> str:
    lines = [clean_line(line) for line in row.get("ocr_lines", [])]
    name = row["name"]
    start_index = 0
    for index, line in enumerate(lines):
        if line == name or name in line:
            start_index = index + 1
            break
    kept: list[str] = []
    for line in lines[start_index:]:
        if is_noise_line(line):
            continue
        kept.append(line)
    return "\n".join(kept).strip()


def detect_keywords(text: str) -> list[str]:
    keywords: list[str] = []
    if "冲锋" in text:
        keywords.append("charge")
    if "进攻距离+1" in text or "远程进攻" in text:
        keywords.append("ranged")
    if "远程进攻无损" in text:
        keywords.append("attack_no_loss")
    if "挑衅" in text or "获得挑" in text:
        keywords.append("taunt")
    if "不可进行支援和进攻" in text or "无法进攻" in text:
        keywords.append("cannot_attack")
    return keywords


def extract_power_from_image(engine, image_path: str) -> int | None:
    from tools.import_cards.extract_rule_cards import parse_lines

    image = Image.open(ROOT / image_path)
    crop = image.crop(POWER_CROP_BOX)
    grayscale = ImageOps.grayscale(crop).resize((crop.width * 4, crop.height * 4))
    temp_path = ROOT / "_tmp_power_crop.png"
    grayscale.save(temp_path)
    result, _ = engine(str(temp_path))
    lines = parse_lines(result or [])
    for line in lines:
        for match in POWER_RE.findall(line.text):
            value = int(match)
            if value >= 1000:
                return value
    return None


def load_existing_power_by_name() -> dict[str, int]:
    if not CARD_OUTPUT.exists():
        return {}
    try:
        rows = load_json(CARD_OUTPUT)
    except Exception:
        return {}
    result: dict[str, int] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        name = str(row.get("name", "")).strip()
        power = int(row.get("power", 0) or 0)
        if name and power > 0:
            result[name] = power
    return result


def apply_card_patch(card: dict, normalized_card_code: str) -> dict:
    patch = IMPLEMENTED_CARD_PATCHES.get(normalized_card_code)
    if not patch:
        return card
    for key, value in patch.items():
        if isinstance(value, list):
            card[key] = json.loads(json.dumps(value, ensure_ascii=False))
        elif isinstance(value, dict):
            card[key] = json.loads(json.dumps(value, ensure_ascii=False))
        else:
            card[key] = value
    return card


def build_cards() -> tuple[list[dict], dict[str, str]]:
    decklists = load_json(RAW_DIR / "starter_duel_decklists.json")
    manifests = []
    for name in MANIFEST_FILES:
        manifests.extend(load_json(RAW_DIR / name))
    by_name = {row["name"]: row for row in manifests}
    alias_to_name: dict[str, str] = {}
    for deck in decklists["decks"]:
        for card in deck["cards"]:
            for alias in card.get("aliases", []):
                alias_to_name[alias] = card["name"]

    existing_power_by_name = load_existing_power_by_name()
    engine = None
    cards: list[dict] = []
    name_to_id: dict[str, str] = {}
    for deck in decklists["decks"]:
        for item in deck["cards"]:
            canonical_name = item["name"]
            if canonical_name in name_to_id:
                continue
            row = by_name.get(canonical_name)
            if row is None:
                for alias, target in alias_to_name.items():
                    if target == canonical_name and alias in by_name:
                        row = dict(by_name[alias])
                        row["name"] = canonical_name
                        break
            if row is None:
                raise ValueError(f"missing manifest row for {canonical_name}")

            card_code = slug_card_code(row)
            normalized_card_code = card_code.upper()
            card_id = "%s_%s" % (
                FACTION_BY_PDF.get(row["pdf"], "neutral"),
                card_code.lower().replace("-", "_"),
            )
            name_to_id[canonical_name] = card_id
            text = extract_text(row)
            card = {
                "id": card_id,
                "name": canonical_name,
                "faction": FACTION_BY_PDF.get(row["pdf"], "neutral"),
                "type": normalize_card_type(row),
                "cost": COST_OVERRIDES.get(normalized_card_code, 0),
                "calamity_level": CALAMITY_LEVEL_OVERRIDES.get(normalized_card_code, 0),
                "status": "raw_imported",
                "keywords": detect_keywords(text),
                "effects": [],
                "text": text,
                "image_path": "res://%s" % row["image_path"].replace("\\", "/"),
                "source": {
                    "rule_pdf": row["pdf"],
                    "page": row["page"],
                    "card_code": card_code,
                    "ocr_name": row["name"],
                    "import_stage": "raw_rule_book_import",
                },
            }
            if card["type"] == "legion":
                power = POWER_OVERRIDES.get(normalized_card_code)
                if power is None:
                    power = existing_power_by_name.get(canonical_name)
                if power is None:
                    if engine is None:
                        from tools.import_cards.extract_rule_cards import RapidOCR

                        engine = RapidOCR()
                    power = extract_power_from_image(engine, row["image_path"])
                if power is not None:
                    card["power"] = power
                    card["hp"] = power
            if canonical_name == "草薙剑":
                card["source"]["ocr_alias"] = "草剑"
            card = apply_card_patch(card, normalized_card_code)
            cards.append(card)

    cards.sort(key=lambda row: row["id"])
    return cards, name_to_id


def build_master_cards() -> tuple[list[dict], dict[str, str]]:
    decklists = load_json(RAW_DIR / "starter_duel_decklists.json")
    manifests = []
    for name in MANIFEST_FILES:
        manifests.extend(load_json(RAW_DIR / name))
    masters: list[dict] = []
    name_to_id: dict[str, str] = {}
    for deck in decklists["decks"]:
        master_name = deck.get("master_name", "")
        if not master_name:
            continue
        if master_name in name_to_id:
            continue
        candidates = []
        for row in manifests:
            if row.get("card_type") == "master" and row.get("name") == master_name:
                candidates.append(row)
        if not candidates:
            raise ValueError(f"missing master row for {master_name}")
        candidates.sort(
            key=lambda row: (
                1 if slug_card_code(row).lower().endswith("a") else 0,
                int(row.get("page", 0)),
            )
        )
        row = candidates[0]
        card_code = slug_card_code(row)
        normalized_card_code = card_code.upper()
        master_id = "%s_%s" % (
            FACTION_BY_PDF.get(row["pdf"], "neutral"),
            card_code.lower().replace("-", "_"),
        )
        name_to_id[master_name] = master_id
        masters.append({
            "id": master_id,
            "name": master_name,
            "faction": FACTION_BY_PDF.get(row["pdf"], "neutral"),
            "kind": "master",
            "hp": MASTER_HP_OVERRIDES.get(master_name, 0),
            "max_hp": MASTER_HP_OVERRIDES.get(master_name, 0),
            "image_path": "res://%s" % row["image_path"].replace("\\", "/"),
            "text": extract_text(row),
            "source": {
                "rule_pdf": row["pdf"],
                "page": row["page"],
                "card_code": card_code,
                "ocr_name": row["name"],
                "import_stage": "raw_rule_book_import",
            },
        })
    masters.sort(key=lambda row: row["id"])
    return masters, name_to_id


def build_deck_preset(name_to_id: dict[str, str], masters: list[dict], master_name_to_id: dict[str, str]) -> dict:
    decklists = load_json(RAW_DIR / "starter_duel_decklists.json")
    master_rows = {row["name"]: row for row in masters}
    preset = {
        "id": "starter_takamagahara_asgard_raw",
        "name": "高天原 vs 阿斯加德（原始导入）",
        "description": "按规则书第1册第6页预组生成；当前已接入关键主宰、战术与圣物的最小可执行效果。",
        "source": {
            "rule_book": "规则/1.pdf",
            "page": 6,
        },
        "players": [],
    }
    for deck in decklists["decks"]:
        deck_cards: list[str] = []
        for card in deck["cards"]:
            deck_cards.extend([name_to_id[card["name"]]] * int(card["count"]))
        preset["players"].append({
            "name": deck["name"],
            "master_name": deck.get("master_name", ""),
            "master_id": master_name_to_id.get(deck.get("master_name", ""), ""),
            "master_hp": int(master_rows.get(deck.get("master_name", ""), {}).get("hp", 20)),
            "master_max_hp": int(master_rows.get(deck.get("master_name", ""), {}).get("max_hp", 20)),
            "deck": deck_cards,
        })
    return preset


def main() -> None:
    cards, name_to_id = build_cards()
    masters, master_name_to_id = build_master_cards()
    preset = build_deck_preset(name_to_id, masters, master_name_to_id)
    CARD_OUTPUT.write_text(json.dumps(cards, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    DECK_OUTPUT.write_text(json.dumps(preset, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    MASTER_OUTPUT.write_text(json.dumps(masters, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(CARD_OUTPUT)
    print(DECK_OUTPUT)
    print(MASTER_OUTPUT)
    print("cards", len(cards))
    print("masters", len(masters))
    print("deck_sizes", [len(player["deck"]) for player in preset["players"]])


if __name__ == "__main__":
    main()
