extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("linne")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

var player1 : LocalGame.Player
var player2 : LocalGame.Player

var simul_choice = 0

func default_game_setup():
	image_loader = CardImageLoader.new(true)
	game_logic = LocalGame.new(image_loader)
	var seed_value = randi()
	game_logic.initialize_game(default_deck, default_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
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

func give_player_specific_gauge_card(player, def_id, card_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card = GameCard.new(card_id, card_def, player.my_id)
	var card_db = game_logic.get_card_database()
	card_db._test_insert_card(card)
	player.gauge.append(card)

func give_specific_cards(p1, id1, p2, id2):
	if p1:
		give_player_specific_card(p1, id1, TestCardId1)
	if p2:
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
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func do_and_validate_strike(player, card_id, ex_card_id = -1):
	assert_true(game_logic.can_do_strike(player))
	assert_true(game_logic.do_strike(player, card_id, false, ex_card_id))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Started, player, card_id)
	if game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Response or game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
		pass
	else:
		fail_test("Unexpected game state after strike")

func do_strike_response(player, card_id, ex_card = -1):
	assert_true(game_logic.do_strike(player, card_id, false, ex_card))
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

func handle_simultaneous_effects(initiator, defender):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		assert_true(game_logic.do_choice(decider, simul_choice), "Failed simuleffect choice")

func execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices,
		init_ex = false, def_ex = false, init_force_discard = [], def_force_discard = [], init_extra_cost = 0, give_cards = true, initiator_goes_first = true):
	var all_events = []
	if give_cards:
		give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		if give_cards:
			give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		do_and_validate_strike(initiator, TestCardId1)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_SetEffects:
		game_logic.do_force_for_effect(initiator, init_force_discard, false)

	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	elif def_card:
		all_events += do_strike_response(defender, TestCardId2)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_SetEffects:
		game_logic.do_force_for_effect(defender, def_force_discard, false)

	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_PayCosts:
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

	handle_simultaneous_effects(initiator, defender)

	if initiator_goes_first:
		for i in range(init_choices.size()):
			assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "not in decision for choice 1")
			assert_true(game_logic.do_choice(initiator, init_choices[i]), "choice 1 failed")
			handle_simultaneous_effects(initiator, defender)
		handle_simultaneous_effects(initiator, defender)
		for i in range(def_choices.size()):
			assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "not in decision for choice 2")
			assert_true(game_logic.do_choice(defender, def_choices[i]), "choice 2 failed")
			handle_simultaneous_effects(initiator, defender)
	else:
		for i in range(def_choices.size()):
			assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "not in decision for choice 2")
			assert_true(game_logic.do_choice(defender, def_choices[i]), "choice 2 failed")
			handle_simultaneous_effects(initiator, defender)
		handle_simultaneous_effects(initiator, defender)
		for i in range(init_choices.size()):
			assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "not in decision for choice 1")
			assert_true(game_logic.do_choice(initiator, init_choices[i]), "choice 1 failed")
			handle_simultaneous_effects(initiator, defender)

	var events = game_logic.get_latest_events()
	all_events += events
	return all_events

func validate_positions(p1, l1, p2, l2):
	assert_eq(p1.arena_location, l1)
	assert_eq(p2.arena_location, l2)

func validate_life(p1, l1, p2, l2):
	assert_eq(p1.life, l1)
	assert_eq(p2.life, l2)

func get_cards_from_hand(player : LocalGame.Player, amount : int):
	var card_ids = []
	for i in range(amount):
		card_ids.append(player.hand[i].id)
	return card_ids

func get_cards_from_gauge(player : LocalGame.Player, amount : int):
	var card_ids = []
	for i in range(amount):
		card_ids.append(player.gauge[i].id)
	return card_ids

##
## Tests start here
##

func test_linne_gauge_boost_superior():
	position_players(player1, 3, player2, 7)
	player1.exceed()
	give_player_specific_gauge_card(player1, 'uni_normal_cross', TestCardId3)
	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(player1.is_card_in_continuous_boosts(TestCardId3))
	assert_false(player1.is_card_in_gauge(TestCardId3))
	execute_strike(player2, player1, "uni_normal_dive", "uni_normal_dive", [], [])
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.continuous_boosts.size(), 0)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 24)

func test_linne_gauge_boost_vanish():
	position_players(player1, 3, player2, 7)
	player1.exceed()
	give_player_specific_gauge_card(player1, 'linne_moongyre', TestCardId3)
	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(player1.is_card_in_continuous_boosts(TestCardId3))
	execute_strike(player1, player2, "uni_normal_assault", "uni_normal_dive", [], [])
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.continuous_boosts.size(), 0)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 25)

func test_linne_cannot_gauge_boost1():
	player1.exceed()
	assert_eq(player1.gauge.size(), 0)
	assert_false(player1.can_do_character_action(0))

func test_linne_cannot_gauge_boost2():
	give_player_specific_gauge_card(player1, 'uni_normal_focus', TestCardId1)
	give_player_specific_gauge_card(player2, 'uni_normal_focus', TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_true(game_logic.do_boost(player2, TestCardId1))
	assert_eq(player1.gauge.size(), 1)
	assert_false(player1.can_do_character_action(0))

func test_linne_sidestep_sweep_misses():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, 'linne_tenaciousmist', TestCardId3)
	give_player_specific_card(player2, 'uni_normal_sweep', TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, TestCardId4))
	assert_true("uni_normal_sweep" in player2.cards_that_will_not_hit)
	execute_strike(player1, player2, "uni_normal_dive", "uni_normal_sweep", [], [])
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 0)
	validate_life(player1, 30, player2, 25)
	assert_false("uni_normal_sweep" in player2.cards_that_will_not_hit)

# works normally when before: advance chosen
func test_linne_flying_swallow1():
	var cards_in_hand_prestrike = player1.hand.size()
	position_players(player1, 3, player2, 7)
	execute_strike(player1, player2, "linne_flyingswallow", "uni_normal_focus", [0], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 26, player2, 27)
	assert_eq(player1.hand.size(), cards_in_hand_prestrike)

#works normally when before:advance not chosen
func test_linne_flying_swallow2():
	var cards_in_hand_prestrike = player1.hand.size()
	position_players(player1, 3, player2, 7)
	execute_strike(player1, player2, "linne_flyingswallow", "uni_normal_focus", [1], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.hand.size(), cards_in_hand_prestrike + 1)

#works correctly in case where it cannot advance
func test_linne_flying_swallow3():
	var cards_in_hand_prestrike = player1.hand.size()
	position_players(player1, 8, player2, 9)
	execute_strike(player1, player2, "linne_flyingswallow", "uni_normal_focus", [0], [])
	validate_positions(player1, 8, player2, 9)
	validate_life(player1, 26, player2, 27)
	assert_eq(player1.hand.size(), cards_in_hand_prestrike + 1)

#works correctly when moved pre-strike
func test_linne_flying_swallow4():
	position_players(player1, 3, player2, 8)
	give_player_specific_card(player1, 'linne_flyingswallow', TestCardId3)
	game_logic.do_boost(player1, TestCardId3)
	game_logic.do_choice(player1, 0)
	validate_positions(player1, 4, player2, 8)
	var cards_in_hand_prestrike = player1.hand.size()
	execute_strike(player1, player2, "linne_flyingswallow", "uni_normal_focus", [1], [])
	validate_positions(player1, 7, player2, 8)
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.hand.size(), cards_in_hand_prestrike + 1)

#works correctly when moved by opponent
func test_linne_flying_swallow5():
	position_players(player1, 5, player2, 6)
	give_player_specific_card(player1, 'uni_normal_sweep', TestCardId3)
	game_logic.do_boost(player1, TestCardId3)
	var cards_in_hand_prestrike = player1.hand.size()
	execute_strike(player1, player2, "linne_flyingswallow", "uni_normal_grasp", [1], [0], false, false, [], [], 0, true, false)
	validate_positions(player1, 8, player2, 6)
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.hand.size(), cards_in_hand_prestrike + 1)

#works correctly with moon gyre
func test_linne_flying_swallow6():
	position_players(player1, 3, player2, 8)
	give_player_specific_card(player1, 'linne_moongyre', TestCardId3)
	game_logic.do_boost(player1, TestCardId3)
	var cards_in_hand_prestrike = player1.hand.size()
	execute_strike(player1, player2, "linne_flyingswallow", "uni_normal_focus", [1], [])
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.hand.size(), cards_in_hand_prestrike)

func test_linne_tenacious_mist():
	position_players(player1, 5, player2, 6)
	execute_strike(player1, player2, "linne_tenaciousmist", "uni_normal_focus", [], [])
	validate_life(player1, 28, player2, 28)

func test_linne_tenacious_mist2():
	simul_choice = 1 #choose second effect first, lose armor then gain
	position_players(player1, 5, player2, 6)
	give_player_specific_card(player1, 'uni_normal_sweep', TestCardId3)
	game_logic.do_boost(player1, TestCardId3)
	execute_strike(player1, player2, "linne_tenaciousmist", "uni_normal_focus", [], [])
	validate_life(player1, 28, player2, 28)

#wins speed tie, has adequate range
func test_linne_diviner1():
	position_players(player1, 2, player2, 8)
	give_gauge(player1, 2)
	give_player_specific_card(player1, 'uni_normal_cross', TestCardId3)
	give_player_specific_card(player2, 'uni_normal_cross', TestCardId4)
	give_player_specific_card(player1, 'uni_normal_sweep', TestCardId5)
	game_logic.do_boost(player1, TestCardId3)
	game_logic.do_boost(player2, TestCardId4)
	game_logic.do_boost(player1, TestCardId5)
	execute_strike(player1, player2, "linne_thediviner", "uni_normal_cross", [], [])
	validate_life(player1, 30, player2, 24)

#out of range
func test_linne_diviner2():
	position_players(player1, 1, player2, 8)
	give_gauge(player1, 2)
	give_player_specific_card(player1, 'uni_normal_cross', TestCardId3)
	give_player_specific_card(player2, 'uni_normal_cross', TestCardId4)
	give_player_specific_card(player1, 'uni_normal_sweep', TestCardId5)
	game_logic.do_boost(player1, TestCardId3)
	game_logic.do_boost(player2, TestCardId4)
	game_logic.do_boost(player1, TestCardId5)
	execute_strike(player1, player2, "linne_thediviner", "uni_normal_cross", [], [])
	validate_life(player1, 30, player2, 30)

#too slow
func test_linne_diviner3():
	position_players(player1, 3, player2, 8)
	give_gauge(player1, 2)
	give_player_specific_card(player1, 'uni_normal_cross', TestCardId3)
	give_player_specific_card(player2, 'uni_normal_cross', TestCardId4)
	game_logic.do_boost(player1, TestCardId3)
	game_logic.do_boost(player2, TestCardId4)
	execute_strike(player1, player2, "linne_thediviner", "uni_normal_cross", [], [])
	validate_life(player1, 30, player2, 30)
