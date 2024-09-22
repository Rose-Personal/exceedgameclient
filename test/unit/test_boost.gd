extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("solbadguy")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

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
				if number != null:
					assert_eq(event['number'], number)
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

func advance_turn(player):
	assert_true(game_logic.do_prepare(player))
	if player.hand.size() > 7:
		var cards = []
		var to_discard = player.hand.size() - 7
		for i in range(to_discard):
			cards.append(player.hand[i].id)
		assert_true(game_logic.do_discard_to_max(player, cards))

func do_and_validate_strike(player, card_id, ex_card_id = -1):
	assert_true(game_logic.can_do_strike(player))
	assert_true(game_logic.do_strike(player, card_id, false, ex_card_id))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Started, player, card_id)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response)

func do_strike_response(player, card_id, ex_card = -1):
	assert_true(game_logic.do_strike(player, card_id, false, ex_card))
	var events = game_logic.get_latest_events()
	return events

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

func execute_strike(initiator, defender, init_card, def_card, init_choices, def_choices, init_ex = false, def_ex = false):
	var all_events = []
	give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		do_and_validate_strike(initiator, TestCardId1)

	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	else:
		all_events += do_strike_response(defender, TestCardId2)

	handle_simultaneous_effects(initiator, defender)
	for i in range(init_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(initiator, init_choices[i]))
		handle_simultaneous_effects(initiator, defender)
		var events = game_logic.get_latest_events()
		all_events += events
	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(defender, def_choices[i]))
		handle_simultaneous_effects(initiator, defender)
		var events = game_logic.get_latest_events()
		all_events += events

	return all_events

func handle_simultaneous_effects(initiator, defender):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		assert_true(game_logic.do_choice(decider, 0), "Failed simuleffect choice")


func validate_positions(p1, l1, p2, l2):
	assert_eq(p1.arena_location, l1)
	assert_eq(p2.arena_location, l2)

func validate_life(p1, l1, p2, l2):
	assert_eq(p1.life, l1)
	assert_eq(p2.life, l2)

func test_grasp_v_wildthrow():
	position_players(player1, 3, player2, 4)
	var events = execute_strike(player1, player2, "gg_normal_grasp", "solbadguy_wildthrow", [0], [], false, false)
	assert_true(events is Array)
	validate_has_event(events, Enums.EventType.EventType_Strike_IgnoredPushPull, player2)
	validate_positions(player1, 5, player2, 4)
	validate_life(player1, 25, player2, 27)

func test_boost_nr_and_grasp_vs_wildthrow():
	var initiator = game_logic.player
	var defender = game_logic.opponent
	give_specific_cards(initiator, "gg_normal_grasp", defender, "solbadguy_wildthrow")
	give_player_specific_card(initiator, "solbadguy_nightraidvortex", TestCardId3)
	give_gauge(initiator, 1)
	position_players(initiator, 3, defender, 4)

	# Boost night raid
	assert_true(game_logic.do_boost(initiator, TestCardId3))
	var events = game_logic.get_latest_events()
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	# Draw to 8 because had 7 to start and used one.
	assert_eq(initiator.hand.size(), 8)
	game_logic.do_discard_to_max(initiator, [initiator.hand[0].id])
	assert_true(game_logic.do_boost_cancel(initiator, [initiator.gauge[0].id], true))
	events = game_logic.get_latest_events()
	assert_eq(initiator.gauge.size(), 0)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	do_and_validate_strike(initiator, TestCardId1)
	events = do_strike_response(defender, TestCardId2)

	# Grasp decision happens but is ignored.
	assert_true(game_logic.do_choice(initiator, 0))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, defender)
	validate_has_event(events, Enums.EventType.EventType_Strike_IgnoredPushPull, defender)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(initiator.arena_location, 3)
	assert_eq(defender.arena_location, 4)

	validate_life(initiator, 30, defender, 26)

func test_ex_wildthrow_vs_focus():
	position_players(player1, 3, player2, 4)
	var events = execute_strike(player1, player2, "solbadguy_wildthrow", "gg_normal_focus", [], [], true, false)
	validate_has_event(events, Enums.EventType.EventType_Strike_IgnoredPushPull, player2)
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, player2)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 24)

func test_boost_wildthrow_into_focus_vs_slash():
	var initiator = game_logic.player
	var defender = game_logic.opponent
	give_player_specific_card(initiator, "solbadguy_wildthrow", TestCardId3)
	give_player_specific_card(defender, "gg_normal_slash", TestCardId4)

	position_players(player1, 3, player2, 4)
	assert_true(game_logic.do_boost(initiator, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_AdvanceTurn, defender)
	assert_true(game_logic.do_change(defender, [], false))
	events = game_logic.get_latest_events()
	assert_eq(game_logic.game_state, Enums.GameState.GameState_DiscardDownToMax)
	# Draw to 8 because had 7 to start and did change 0.
	assert_eq(defender.hand.size(), 8)
	assert_true(game_logic.do_discard_to_max(defender, [defender.hand[0].id]))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_AdvanceTurn, initiator)
	events = execute_strike(player1, player2, "gg_normal_focus", "gg_normal_slash", [], [], false, false)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player1, 2)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player2, 5)
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, player2)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 28, player2, 25)

func test_double_boost_ride_stun_vs_cross():
	var initiator = game_logic.player
	var defender = game_logic.opponent
	give_gauge(initiator, 3)
	give_player_specific_card(initiator, "kykisuke_ridethelightning", TestCardId3)
	give_player_specific_card(initiator, "kykisuke_ridethelightning", TestCardId4)
	give_player_specific_card(defender, "gg_normal_slash", TestCardId5)

	position_players(player1, 2, player2, 4)
	assert_true(game_logic.do_boost(initiator, TestCardId3))
	assert_true(game_logic.do_boost_cancel(initiator, [initiator.gauge[0].id], true))
	assert_true(game_logic.do_boost(initiator, TestCardId4))
	assert_true(game_logic.do_boost_cancel(initiator, [initiator.gauge[0].id], false))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_AdvanceTurn, defender)
	assert_true(game_logic.do_change(defender, [], false))
	events = game_logic.get_latest_events()
	assert_eq(game_logic.game_state, Enums.GameState.GameState_DiscardDownToMax)
	# Draw to 8 because had 7 to start and did change 0.
	assert_eq(defender.hand.size(), 8)
	assert_true(game_logic.do_discard_to_max(defender, [defender.hand[0].id]))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_AdvanceTurn, initiator)

	events = execute_strike(player1, player2, "kykisuke_stunedge", "gg_normal_cross", [], [], false, false)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player1, 3)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player2, 5)
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, player2)
	validate_positions(player1, 2, player2, 7)
	validate_life(player1, 27, player2, 25)

func test_wildthrow_boost_grasp_vs_grasp():
	position_players(player1, 3, player2, 4)
	player1.discard([player1.hand[0].id])
	give_player_specific_card(player1, "gg_normal_grasp", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	var events = execute_strike(player1, player2, "solbadguy_wildthrow", "gg_normal_grasp", [], [0], false, false)
	validate_has_event(events, Enums.EventType.EventType_Strike_IgnoredPushPull, player1)
	assert_eq(player1.gauge.size(), 2)
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 27, player2, 24)
