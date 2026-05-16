extends RefCounted
class_name RngService

var seed: int = 1
var state: int = 1

func _init(p_seed: int = 1):
    seed = p_seed
    state = max(1, p_seed)

func next_int(max_exclusive: int) -> int:
    if max_exclusive <= 0:
        return 0
    state = int((state * 1103515245 + 12345) & 0x7fffffff)
    return state % max_exclusive
