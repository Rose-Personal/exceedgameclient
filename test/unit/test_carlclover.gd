extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("carlclover")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

var player1 : LocalGame.Player
var player2 : LocalGame.Player

func default_game_setup(alt_opponent : String = ""):
	var opponent_deck = default_deck
	if alt_opponent:
		opponent_deck = CardDefinitions.get_deck_from_str_id(alt_opponent)
	image_loader = CardImageLoader.new(true)
	game_logic = LocalGame.new(image_loader)
	var seed_value = randi()
	game_logic.initialize_game(default_deck, opponent_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.player, [])
	game_logic.do_mulligan(game_logic.opponent, [])
	player1 = game_logic.player
	player2 = game_logic.opponent
	game_logic.get_latest_events()

func give_player_specific_card(player, def_id, card_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card = GameCard.new(card_id, card_def, player.my_id)
	var card_db = game_logic.get_card_database()
	card_db._test_insert_card(card)
	player.hand.append(card)

func give_specific_cards(p1, id1, p2, id2):
	if p1 and id1:
			give_player_specific_card(p1, id1, TestCardId1)
	if p2 and id2:
		give_player_specific_card(p2, id2, TestCardId2)

func position_players(p1, loc1, p2, loc2):
	p1.arena_location = loc1
	p2.arena_location = loc2

func give_gauge(player, amount):
	for i in range(amount):
		player.add_to_gauge(player.deck[0])
		player.deck.remove_at(0)

func validate_has_event(events, event_type, target_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			if event['event_player'] == target_player.my_id:
				if number != null and event['number'] == number:
					return
				elif number == null:
					return
	fail_test("Event not found: %s" % event_type)

func before_each():
	default_game_setup()

	gut.p("ran setup", 2)

func after_each():
	game_logic.teardown()
	game_logic.free()
	image_loader.free()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func do_and_validate_strike(player, card_id, ex_card_id = -1):
	assert_true(game_logic.can_do_strike(player))
	var wild_swing = card_id == -1
	assert_true(game_logic.do_strike(player, card_id, wild_swing, ex_card_id))
	var events = game_logic.get_latest_events()
	if card_id == -1:
		card_id = null
	validate_has_event(events, Enums.EventType.EventType_Strike_Started, player, card_id)
	if game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Response or game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
		pass
	else:
		fail_test("Unexpected game state after strike")

func do_strike_response(player, card_id, ex_card = -1):
	var wild_swing = card_id == -1
	assert_true(game_logic.do_strike(player, card_id, wild_swing, ex_card))
	var events = game_logic.get_latest_events()
	return events

func advance_turn(player):
	assert_true(game_logic.do_prepare(player))
	if player.hand.size() > 7:
		var cards = []
		var to_discard = player.hand.size() - 7
		for i in range(to_discard):
			cards.append(player.hand[i].id)
		assert_true(game_logic.do_discard_to_max(player, cards))

func validate_gauge(player, amount, id):
	assert_eq(len(player.gauge), amount)
	if len(player.gauge) != amount: return
	if amount == 0: return
	for card in player.gauge:
		if card.id == id:
			return
	fail_test("Didn't have required card in gauge.")

func validate_discard(player, amount, id):
	assert_eq(len(player.discards), amount)
	if len(player.discards) != amount: return
	if amount == 0: return
	for card in player.discards:
		if card.id == id:
			return
	fail_test("Didn't have required card in discard.")

func handle_simultaneous_effects(initiator, defender, simul_effect_choices : Array):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		var choice = 0
		if len(simul_effect_choices) > 0:
			choice = simul_effect_choices[0]
			simul_effect_choices.remove_at(0)
		assert_true(game_logic.do_choice(decider, choice), "Failed simuleffect choice")

func execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices, init_ex = false, def_ex = false, init_force_discard = [], def_force_discard = [], init_extra_cost = 0, simul_effect_choices = []):
	var all_events = []
	give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		if init_card:
			do_and_validate_strike(initiator, TestCardId1)
		else:
			# Wild swing
			do_and_validate_strike(initiator, -1)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_SetEffects:
		if game_logic.decision_info.type == Enums.DecisionType.DecisionType_GaugeForEffect:
			assert_true(game_logic.do_gauge_for_effect(initiator, init_force_discard), "failed gauge for effect in execute_strike")
		elif game_logic.decision_info.type == Enums.DecisionType.DecisionType_ForceForEffect:
			assert_true(game_logic.do_force_for_effect(initiator, init_force_discard, false), "failed force for effect in execute_strike")

	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	elif def_card:
		all_events += do_strike_response(defender, TestCardId2)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_SetEffects:
		game_logic.do_force_for_effect(defender, def_force_discard, false)

	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_PayCosts:
		if game_logic.active_strike.initiator_card.definition['force_cost']:
			var cost = game_logic.active_strike.initiator_card.definition['force_cost'] + init_extra_cost
			var cards = []
			for i in range(cost):
				cards.append(initiator.hand[i].id)
			game_logic.do_pay_strike_cost(initiator, cards, false)
		else:
			var cost = game_logic.active_strike.initiator_card.definition['gauge_cost'] + init_extra_cost
			var cards = []
			for i in range(cost):
				cards.append(initiator.gauge[i].id)
			game_logic.do_pay_strike_cost(initiator, cards, false)

	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_PayCosts:
		var cost = game_logic.active_strike.defender_card.definition['gauge_cost']
		var cards = []
		for i in range(cost):
			cards.append(defender.gauge[i].id)
		game_logic.do_pay_strike_cost(defender, cards, false)

	handle_simultaneous_effects(initiator, defender, simul_effect_choices)

	for i in range(init_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(initiator, init_choices[i]))
		handle_simultaneous_effects(initiator, defender, simul_effect_choices)
	handle_simultaneous_effects(initiator, defender, simul_effect_choices)

	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(defender, def_choices[i]))
		handle_simultaneous_effects(initiator, defender, simul_effect_choices)

	var events = game_logic.get_latest_events()
	all_events += events
	return all_events

func validate_positions(p1, l1, p2, l2):
	assert_eq(p1.arena_location, l1)
	assert_eq(p2.arena_location, l2)

func validate_life(p1, l1, p2, l2):
	assert_eq(p1.life, l1)
	assert_eq(p2.life, l2)

##
## Tests start here
##
func test_carlclover_vs_hazama_get_bonus_when_he_moves():
	game_logic.teardown()
	game_logic.free()
	image_loader.free()
	default_game_setup("hazama")
	position_players(player1, 3, player2, 4)
	player1.set_buddy_location("nirvana_active", 4)
	advance_turn(player1)
	give_player_specific_card(player2, "standard_normal_cross", TestCardId3)
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1))
	# As Hazama sets, has has ouroboros effect
	assert_true(game_logic.do_force_for_effect(player2, [player2.hand[0].id], false, false))
	# Choose which snake to use
	assert_true(game_logic.do_choice(player2, 1))
	# Choose where to place it
	assert_true(game_logic.do_choice(player2, 1))
	# Carl attacks
	give_player_specific_card(player1, "carlclover_conbrio", TestCardId4)
	assert_true(game_logic.do_strike(player1, TestCardId4, false, -1))
	# Cards revealed and Hazama has moved
	validate_positions(player1, 3, player2, 5)
	# Cards has to pay for his attack
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	# The rest of the attack plays out
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 26)


func test_carlclover_exceed_normal():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 4)
	player1.exceed()
	assert_eq(player1.get_buddy_location("nirvana_active"), 4)

func test_carlclover_exceed_when_disabled():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", -1)
	player1.set_buddy_location("nirvana_disabled", 4)
	player1.exceed()
	assert_eq(player1.get_buddy_location("nirvana_active"), 4)

func test_carlclover_disable_nirvana():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 4)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [0], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 24)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	assert_eq(player1.get_buddy_location("nirvana_active"), -1)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), 4)
	advance_turn(player2)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), 4)

func test_carlclover_disable_nirvana2():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 6)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [0], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 24)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	assert_eq(player1.get_buddy_location("nirvana_active"), -1)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), 6)
	advance_turn(player2)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), 6)

func test_carlclover_disable_nirvana_pass():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 4)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [1], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 24, player2, 24)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	assert_eq(player1.get_buddy_location("nirvana_active"), 4)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), -1)
	advance_turn(player2)

func test_carlclover_exceed_skip_disable_choice():
	position_players(player1, 3, player2, 6)
	player1.exceed()
	player1.set_buddy_location("nirvana_active", 4)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 24, player2, 24)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	assert_eq(player1.get_buddy_location("nirvana_active"), 4)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), -1)
	advance_turn(player2)

func test_carlclover_disabled_skip_disable_choice_then_reactivated():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", -1)
	player1.set_buddy_location("nirvana_disabled", 4)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [0], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 24, player2, 24)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	assert_eq(player1.get_buddy_location("nirvana_active"), 4)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), -1)
	advance_turn(player2)

func test_carlclover_nirvana_powerup_not_normal():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 7)
	player2.set_buddy_location("nirvana_active", 1)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)

func test_carlclover_nirvana_powerup_special():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 7)
	player2.set_buddy_location("nirvana_active", 1)
	execute_strike(player1, player2, "carlclover_confuoco", "standard_normal_assault", [], [], false, false, [], [], 1, [])
	assert_true(game_logic.do_force_for_effect(player1, [], false, true))
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 23)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 0)
	advance_turn(player1)

func test_carlclover_nirvana_powerup_not_special():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 4)
	player2.set_buddy_location("nirvana_active", 1)
	execute_strike(player1, player2, "carlclover_confuoco", "standard_normal_assault", [], [1], false, false, [], [], 1, [])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)

func test_carlclover_confuoco_beforemove():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("nirvana_active", 9)
	player2.set_buddy_location("nirvana_active", 1)
	execute_strike(player1, player2, "carlclover_confuoco", "standard_normal_assault", [], [], false, false, [], [], 1, [])
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false))
	# Choices are locations [7, 8]
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.get_buddy_location("nirvana_active"), 8)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 23)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 0)
	advance_turn(player1)

func test_carlclover_conanima_miss_draw():
	position_players(player1, 1, player2, 6)
	player1.set_buddy_location("nirvana_active", 9)
	player2.set_buddy_location("nirvana_active", 1)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "carlclover_conanima", "standard_normal_assault", [1], [], false, false, [], [], 0, [])
	validate_positions(player1, 1, player2, 4)
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player2.gauge.size(), 0)
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)

func test_carlclover_conbrio_attack_in_space():
	position_players(player1, 4, player2, 6)
	player1.set_buddy_location("nirvana_active", 6)
	player2.set_buddy_location("nirvana_active", 9)
	execute_strike(player1, player2, "carlclover_conbrio", "standard_normal_assault", [0], [], false, false, [], [], 0, [])
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 26)

func test_carlclover_conbrio_boost_move():
	position_players(player1, 1, player2, 6)
	player1.set_buddy_location("nirvana_active", 3)
	give_player_specific_card(player1, "carlclover_conbrio", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.get_buddy_location("nirvana_active"), 2)
	advance_turn(player1)

func test_carlclover_conbrio_boost_flip():
	position_players(player1, 1, player2, 6)
	player1.set_buddy_location("nirvana_active", -1)
	player1.set_buddy_location("nirvana_disabled", 3)
	give_player_specific_card(player1, "carlclover_conbrio", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_eq(player1.get_buddy_location("nirvana_active"), 3)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), -1)
	advance_turn(player1)

func test_carlclover_cantabile_active_do_move():
	position_players(player1, 4, player2, 6)
	player1.set_buddy_location("nirvana_active", 5)
	player2.set_buddy_location("nirvana_active", 9)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "carlclover_cantabile", "standard_normal_assault", [0, 2], [], false, false, [], [], 0, [])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 29)
	assert_eq(player1.get_buddy_location("nirvana_active"), 6)
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 0)
	advance_turn(player1)

func test_carlclover_cantabile_disabled_skip_move():
	position_players(player1, 4, player2, 6)
	player1.set_buddy_location("nirvana_active", -1)
	player1.set_buddy_location("nirvana_disabled", 5)
	player2.set_buddy_location("nirvana_active", 9)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "carlclover_cantabile", "standard_normal_assault", [0, 0], [], false, false, [], [], 0, [])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 29)
	assert_eq(player1.get_buddy_location("nirvana_active"), 5)
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 0)
	advance_turn(player1)

func test_carlclover_volante_powerup():
	position_players(player1, 3, player2, 4)
	player1.set_buddy_location("nirvana_active", 7)
	player2.set_buddy_location("nirvana_active", 9)
	execute_strike(player1, player2, "carlclover_volante", "standard_normal_assault", [0], [], false, false, [], [], 0, [])
	validate_positions(player1, 5, player2, 4)
	validate_life(player1, 27, player2, 24)
	advance_turn(player1)

func test_carlclover_rhapsody_cantflip():
	position_players(player1, 4, player2, 9)
	give_gauge(player1, 3)
	player1.set_buddy_location("nirvana_active", 6)
	player2.set_buddy_location("nirvana_active", 9)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "carlclover_rhapsodyofmemories", "standard_normal_assault", [1], [], false, false, [], [], 0, [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 25)
	assert_eq(player1.get_buddy_location("nirvana_active"), 6)
	assert_eq(player1.hand.size(), 7)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 0)
	advance_turn(player2)

func test_carlclover_laetabilis_flip():
	position_players(player1, 4, player2, 6)
	give_gauge(player1, 2)
	player1.set_buddy_location("nirvana_active", -1)
	player1.set_buddy_location("nirvana_disabled", 3)
	player2.set_buddy_location("nirvana_active", 9)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "carlclover_laetabiliscantata", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 26, player2, 27)
	assert_eq(player1.get_buddy_location("nirvana_active"), 3)
	assert_eq(player1.hand.size(), 4)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)

func test_carlclover_laetabilis_active_move():
	position_players(player1, 4, player2, 6)
	give_gauge(player1, 2)
	player1.set_buddy_location("nirvana_active", 1)
	player2.set_buddy_location("nirvana_active", 9)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "carlclover_laetabiliscantata", "standard_normal_sweep", [2], [], false, false, [], [], 0, [])
	assert_eq(player1.get_buddy_location("nirvana_active"), 3)
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 26, player2, 27)
	assert_eq(player1.hand.size(), 4)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)

func test_carlclover_laetabilis_boost():
	position_players(player1, 4, player2, 6)
	give_player_specific_card(player1, "carlclover_laetabiliscantata", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	player1.set_buddy_location("nirvana_active", -1)
	player1.set_buddy_location("nirvana_disabled", 6)
	player2.set_buddy_location("nirvana_active", 9)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [0], [], false, false, [], [], 0, [])
	assert_eq(player1.get_buddy_location("nirvana_active"), 6)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 23)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 0)
	advance_turn(player1)

func test_carlclover_deusexmachina_sealed():
	advance_turn(player1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId4)
	assert_true(game_logic.do_boost(player2, TestCardId4))
	position_players(player1, 4, player2, 6)
	give_gauge(player1, 4)
	player1.set_buddy_location("nirvana_active", 6)
	player2.set_buddy_location("nirvana_active", 9)
	execute_strike(player1, player2, "carlclover_deusexmachina", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	assert_eq(player1.get_buddy_location("nirvana_active"), -1)
	assert_eq(player1.get_buddy_location("nirvana_disabled"), -1)
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 28, player2, 19)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)

func test_carlclover_invalidate_wildswing_normal_lose_bonus():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId3)
	player1.move_card_from_hand_to_deck(TestCardId3, 0)
	player1.set_buddy_location("nirvana_active", 7)
	player2.set_buddy_location("nirvana_active", 9)
	execute_strike(player1, player2, "carlclover_laetabiliscantata", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	# Player 2 gets simul choice between close and disable, close is chosen first by default.
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.discards.size(), 2)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)
