extends GutTest


var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("enkidu")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005
const TestCardId6 = 50006
const TestCardId7 = 50007
const TestCardId8 = 50008
const TestCardId9 = 50009

var player1 : LocalGame.Player
var player2 : LocalGame.Player

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
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func do_and_validate_strike(player, card_id, ex_card_id = -1):
	assert_true(game_logic.can_do_strike(player))
	if card_id != -1:
		assert_true(game_logic.do_strike(player, card_id, false, ex_card_id))
	else:
		var ws_card_id = player.deck[0].id
		assert_true(game_logic.do_strike(player, card_id, true, ex_card_id))
		card_id = ws_card_id

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

	if init_card:
		if init_ex:
			give_player_specific_card(initiator, init_card, TestCardId3)
			do_and_validate_strike(initiator, TestCardId1, TestCardId3)
		else:
			do_and_validate_strike(initiator, TestCardId1)
	else:
		do_and_validate_strike(initiator, -1)

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

func test_enkidu_ua_success():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "enkidu_threepreceptstrike", TestCardId1)
	player1.discard([TestCardId1])

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(player1.is_card_in_hand(TestCardId1))
	validate_positions(player1, 4, player2, 7)
	advance_turn(player2)

func test_enkidu_ua_fail():
	position_players(player1, 3, player2, 7)
	assert_true(game_logic.do_character_action(player1, []))
	validate_positions(player1, 3, player2, 7)
	advance_turn(player2)

func test_enkidu_exceed_ua_success():
	position_players(player1, 4, player2, 7)
	player1.exceed()
	give_player_specific_card(player1, "enkidu_threepreceptstrike", TestCardId3)
	player1.move_card_from_hand_to_gauge(TestCardId3)

	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "uni_normal_sweep", "uni_normal_spike", [], [], false, false)
	assert_true(player1.is_card_in_sealed(TestCardId3))
	validate_life(player1, 30, player2, 22)
	advance_turn(player2)

func test_enkidu_exceed_ua_fail():
	position_players(player1, 4, player2, 7)
	player1.exceed()
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "uni_normal_sweep", "uni_normal_spike", [], [], false, false)
	validate_life(player1, 25, player2, 30)
	advance_turn(player2)

func test_enkidu_no_precepts_hit():
	position_players(player1, 4, player2, 7)
	player1.discard_hand()
	execute_strike(player1, player2, "enkidu_threepreceptstrike", "uni_normal_sweep", [0], [], false, false)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 24, player2, 27)
	advance_turn(player2)

func test_enkidu_no_precepts_stunned():
	position_players(player1, 6, player2, 8)
	execute_strike(player1, player2, "enkidu_threepreceptstrike", "uni_normal_cross", [], [], false, false)
	validate_positions(player1, 6, player2, 9)
	validate_life(player1, 27, player2, 30)
	advance_turn(player2)

func test_enkidu_three_precepts():
	position_players(player1, 6, player2, 8)
	for card_id in [TestCardId3, TestCardId4, TestCardId5]:
		give_player_specific_card(player1, "enkidu_threepreceptstrike", card_id)
		player1.move_card_from_hand_to_gauge(card_id)

	execute_strike(player1, player2, "enkidu_threepreceptstrike", "uni_normal_cross", [1], [], false, false)
	validate_positions(player1, 7, player2, 9)
	validate_life(player1, 27, player2, 24)
	advance_turn(player2)

func test_enkidu_five_precepts():
	position_players(player1, 6, player2, 3)
	for card_id in [TestCardId3, TestCardId4, TestCardId5, TestCardId6, TestCardId7]:
		give_player_specific_card(player1, "enkidu_threepreceptstrike", card_id)
		player1.move_card_from_hand_to_gauge(card_id)

	execute_strike(player1, player2, "enkidu_threepreceptstrike", "uni_normal_sweep", [1], [], false, false)
	validate_positions(player1, 5, player2, 3)
	validate_life(player1, 30, player2, 22)
	advance_turn(player2)

func test_enkidu_three_precept_strike_advantage():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "enkidu_threepreceptstrike", TestCardId3)
	execute_strike(player1, player2, "enkidu_threepreceptstrike", "uni_normal_sweep", [0], [], false, false)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 24, player2, 27)
	advance_turn(player1)

func test_enkidu_calamity_crest():
	position_players(player1, 6, player2, 8)
	for card_id in [TestCardId3, TestCardId4, TestCardId5]:
		give_player_specific_card(player1, "enkidu_threepreceptstrike", card_id)

	for card_id in [TestCardId3, TestCardId4, TestCardId5]:
		assert_true(game_logic.do_boost(player1, card_id, []))
		assert_true(player1.is_card_in_gauge(card_id))
	assert_eq(player1.life, 21)

	execute_strike(player1, player2, "enkidu_threepreceptstrike", "uni_normal_cross", [1], [], false, false)
	validate_positions(player1, 7, player2, 9)
	validate_life(player1, 18, player2, 24)
	advance_turn(player2)

func test_enkidu_chained_kick_no_precepts_hit():
	position_players(player1, 4, player2, 7)
	execute_strike(player1, player2, "enkidu_chainedkick", "uni_normal_sweep", [], [], false, false)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 24, player2, 26)
	advance_turn(player2)

func test_enkidu_chained_kick_no_precepts_stunned():
	position_players(player1, 3, player2, 7)
	execute_strike(player1, player2, "enkidu_chainedkick", "uni_normal_dive", [], [], false, false)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 25, player2, 30)
	advance_turn(player2)

func test_enkidu_chained_kick_three_precepts():
	position_players(player1, 3, player2, 7)
	for card_id in [TestCardId3, TestCardId4, TestCardId5]:
		give_player_specific_card(player1, "enkidu_threepreceptstrike", card_id)
		player1.move_card_from_hand_to_gauge(card_id)

	execute_strike(player1, player2, "enkidu_chainedkick", "uni_normal_dive", [], [], false, false)
	validate_positions(player1, 5, player2, 4)
	validate_life(player1, 25, player2, 23)
	advance_turn(player2)

func test_enkidu_reckless_run_no_force():
	position_players(player1, 1, player2, 7)
	give_player_specific_card(player1, "enkidu_chainedkick", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	validate_positions(player1, 3, player2, 7)
	advance_turn(player2)

func test_enkidu_reckless_run_several_force():
	position_players(player1, 1, player2, 7)
	give_player_specific_card(player1, "enkidu_chainedkick", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id, player1.hand[3].id], true))
	validate_positions(player1, 8, player2, 7)
	advance_turn(player2)

func test_enkidu_maelstrom_three_cards():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	player1.draw(3)

	give_player_specific_card(player1, "enkidu_thunderstomp", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	assert_eq(len(player1.hand), 4)
	assert_true(game_logic.do_prepare(player1))
	advance_turn(player2)

func test_enkidu_maelstrom_less_than_three_cards():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	player1.draw(2)

	give_player_specific_card(player1, "enkidu_thunderstomp", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	assert_eq(len(player1.hand), 5) # after end of turn draw
	advance_turn(player2)

func test_enkidu_tidal_spin_initiate():
	position_players(player1, 5, player2, 6)
	execute_strike(player1, player2, "enkidu_tidalspin", "uni_normal_assault", [], [], false, false)
	validate_positions(player1, 8, player2, 6)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_enkidu_tidal_spin_not_initiate():
	position_players(player1, 5, player2, 6)
	advance_turn(player1)
	execute_strike(player2, player1, "uni_normal_assault", "enkidu_tidalspin",  [], [], false, false)
	validate_positions(player1, 8, player2, 7)
	validate_life(player1, 26, player2, 25)
	advance_turn(player2)

func test_enkidu_immovable_object_no_sustain():
	position_players(player1, 5, player2, 6)
	give_player_specific_card(player1, "enkidu_spiraldualpalmstrike", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))

	execute_strike(player2, player1, "uni_normal_grasp", "uni_normal_sweep", [1], [], false, false)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 28, player2, 24)
	assert_true(player1.is_card_in_discards(TestCardId3))
	advance_turn(player1)

func test_enkidu_immovable_object_sustain():
	position_players(player1, 5, player2, 6)
	give_gauge(player1, 1)
	give_player_specific_card(player1, "enkidu_spiraldualpalmstrike", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))

	execute_strike(player2, player1, "uni_normal_grasp", "uni_normal_sweep", [1], [], false, false)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 28, player2, 24)
	assert_true(game_logic.do_gauge_for_effect(player1, [player1.gauge[0].id]))
	assert_true(player1.is_card_in_continuous_boosts(TestCardId3))
	advance_turn(player1)

func test_enkidu_immovable_object_double_sustain():
	# Tests if losing one source of ignore_push_and_pull preserves the other
	position_players(player1, 5, player2, 6)
	give_gauge(player1, 1)
	give_player_specific_card(player1, "enkidu_spiraldualpalmstrike", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	advance_turn(player2)
	give_player_specific_card(player1, "enkidu_spiraldualpalmstrike", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId4, []))

	execute_strike(player2, player1, "uni_normal_grasp", "uni_normal_sweep", [1], [], false, false)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 29, player2, 24)
	assert_true(game_logic.do_gauge_for_effect(player1, [player1.gauge[0].id]))
	assert_true(player1.is_card_in_continuous_boosts(TestCardId3))
	assert_true(player1.is_card_in_discards(TestCardId4))
	advance_turn(player1)

	execute_strike(player2, player1, "uni_normal_grasp", "uni_normal_sweep", [1], [], false, false)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 27, player2, 18)
	assert_true(game_logic.do_gauge_for_effect(player1, []))
	assert_true(player1.is_card_in_discards(TestCardId3))
	advance_turn(player1)

func test_enkidu_immovable_object_gone_after_discard():
	position_players(player1, 5, player2, 6)
	give_player_specific_card(player1, "enkidu_spiraldualpalmstrike", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))

	execute_strike(player2, player1, "uni_normal_grasp", "uni_normal_sweep", [1], [], false, false)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 28, player2, 24)
	assert_true(player1.is_card_in_discards(TestCardId3))

	execute_strike(player1, player2, "uni_normal_sweep", "uni_normal_grasp", [], [1], false, false)
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 25, player2, 18)
	advance_turn(player2)

func test_enkidu_immovable_object_gone_after_tech():
	position_players(player1, 5, player2, 6)
	give_player_specific_card(player1, "enkidu_spiraldualpalmstrike", TestCardId3)
	give_player_specific_card(player2, "uni_normal_block", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId3, []))

	assert_true(game_logic.do_boost(player2, TestCardId4, []))
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, TestCardId3))
	execute_strike(player2, player1, "uni_normal_grasp", "uni_normal_sweep", [1], [], false, false)
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 27, player2, 24)
	assert_true(player1.is_card_in_discards(TestCardId3))
	advance_turn(player1)

func test_enkidu_demon_seal_full_cost():
	position_players(player1, 4, player2, 6)
	for card_id in [TestCardId3, TestCardId4, TestCardId5, TestCardId6, TestCardId7, TestCardId8]:
		give_player_specific_card(player1, "uni_normal_grasp", card_id)
		player1.move_card_from_hand_to_gauge(card_id)

	execute_strike(player1, player2, "enkidu_demonsealabyssalforce", "uni_normal_focus", [], [], false, false)
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 30, player2, 22)
	assert_eq(len(player1.gauge), 1)
	advance_turn(player1)

func test_enkidu_demon_seal_half_cost():
	position_players(player1, 4, player2, 6)
	for card_id in [TestCardId3, TestCardId4, TestCardId5]:
		give_player_specific_card(player1, "uni_normal_grasp", card_id)
		player1.move_card_from_hand_to_gauge(card_id)
	for card_id in [TestCardId6, TestCardId7, TestCardId8]:
		give_player_specific_card(player1, "enkidu_threepreceptstrike", card_id)
		player1.move_card_from_hand_to_gauge(card_id)

	execute_strike(player1, player2, "enkidu_demonsealabyssalforce", "uni_normal_focus", [], [], false, false,
		[], [], -3)
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 30, player2, 22)
	assert_true(game_logic.do_gauge_for_effect(player1, []))
	assert_eq(len(player1.gauge), 4)
	advance_turn(player1)

func test_enkidu_demon_seal_free_return_precepts():
	position_players(player1, 4, player2, 6)
	for card_id in [TestCardId9]:
		give_player_specific_card(player1, "uni_normal_grasp", card_id)
		player1.move_card_from_hand_to_gauge(card_id)
	for card_id in [TestCardId3, TestCardId4, TestCardId5, TestCardId6, TestCardId7, TestCardId8]:
		give_player_specific_card(player1, "enkidu_threepreceptstrike", card_id)
		player1.move_card_from_hand_to_gauge(card_id)

	execute_strike(player1, player2, "enkidu_demonsealabyssalforce", "uni_normal_focus", [], [], false, false,
		[], [], -6)
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 30, player2, 22)
	assert_true(game_logic.do_gauge_for_effect(player1, [TestCardId3, TestCardId4, TestCardId5]))
	assert_eq(len(player1.gauge), 5)
	for card_id in [TestCardId3, TestCardId4, TestCardId5]:
		assert_true(player1.is_card_in_hand(card_id))
	for card_id in [TestCardId6, TestCardId7, TestCardId8, TestCardId9]:
		assert_true(player1.is_card_in_gauge(card_id))
	advance_turn(player1)

func test_enkidu_unstoppable_force_no_sustain():
	position_players(player1, 5, player2, 6)
	give_player_specific_card(player1, "enkidu_demonsealabyssalforce", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_cross", "uni_normal_sweep", [], [], false, false)
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 27)
	assert_true(player1.is_card_in_discards(TestCardId3))
	advance_turn(player1)

func test_enkidu_unstoppable_force_sustain():
	position_players(player1, 5, player2, 6)
	give_gauge(player1, 1)
	give_player_specific_card(player1, "enkidu_demonsealabyssalforce", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_cross", "uni_normal_sweep", [], [], false, false)
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 27)
	assert_true(game_logic.do_gauge_for_effect(player1, [player1.gauge[0].id]))
	assert_true(player1.is_card_in_continuous_boosts(TestCardId3))
	advance_turn(player1)
