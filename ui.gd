class_name UI extends Control

var file_location: String

@onready var ip: Label = $IP
@onready var status: Label = $status
@onready var ipinput: TextEdit = $TextEdit

func _ready() -> void:
	ip.set_text(str(IP.get_local_addresses()))

func _on_send_button_pressed() -> void:
	if send_mode:
		if !peer:
			return connect_to_server(ipinput.get_text())
	else:
		if !peer:
			return create_server(DEFAULT_PORT)
	if file_location.is_empty():
		return printerr("file location is empty")
	if !file_location.is_valid_filename():
		return printerr("invalid filename")
	if send_mode == true:
		send.bind(FileAccess.get_file_as_bytes(file_location)).rpc()
	else:
		printerr("receiving, not pitching.")

func bytes_to_json(bytes: PackedByteArray) -> void:
	var file := FileAccess.open(file_location,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.flush()
	file.close()

enum {DISCONNECTED = -1, HOST, SERVER}
const localhost = 'localhost'
const loopback = '127.0.0.1'
enum {DEFAULT_PORT = 25565, DEFAULT_BROWSER_PORT = 42069, DEFAULT_LOCAL_BROWSER_PORT = 25566}

var peer: ENetMultiplayerPeer

func create_server(port: int) -> void:
	print("Attempting to host on port %s."%port)
	reset_if_connected()
	setup_new_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	peer.create_server(port,1)
	print("Created server on port %s"%port)
	setup_server_connections()
	assign_multiplayer_peer(peer)
	status.set_text("server")

func setup_new_peer(mode: int = SERVER) -> void:
	assert(mode == SERVER or mode == MultiplayerPeer.TARGET_PEER_BROADCAST,"Targeting mode %s is incorrect. Target mode either needs to be set to target the server, %s, or set to broadcast, %s."%[mode,SERVER,MultiplayerPeer.TARGET_PEER_BROADCAST])
	var new_peer := ENetMultiplayerPeer.new()
	new_peer.set_target_peer(mode)
	new_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	peer = new_peer

func assign_multiplayer_peer(new_peer: MultiplayerPeer) -> void:
	multiplayer.set_multiplayer_peer(new_peer)

func reset() -> void:
	print("Resetting peer")
	if peer:
		peer.close()
	peer = null
	assign_multiplayer_peer(OfflineMultiplayerPeer.new())
	@warning_ignore("static_called_on_instance")
	disconnect_all_signals(multiplayer)
	# disconnect peer connections
	# disconnect tick funcs
	# reset vars
	# emit network ended signal
	# save history
	# this is hacky and dumb as fuck

func multiplayer_connected() -> bool:
	return peer != null

func reset_if_connected() -> void:
	if multiplayer_connected():
		reset()

func get_sender_id() -> int:
	return multiplayer.get_remote_sender_id()

func connect_to_server(sip: String = localhost, port: int = DEFAULT_PORT) -> void:
	print("Attempting to connect to server %s on port %s"%[sip,port])
	reset_if_connected()
	setup_new_peer()
	peer.create_client(sip,port)
	assign_multiplayer_peer(peer)
	setup_client_connecting_connections()

func setup_client_connecting_connections() -> void:
	multiplayer.connected_to_server.connect(on_connection_succeeded)
	multiplayer.connection_failed.connect(on_connection_failed)

func setup_server_connections() -> void:
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

func setup_client_connections() -> void:
	multiplayer.server_disconnected.connect(on_server_disconnected)

func is_server() -> bool:
	return multiplayer.get_unique_id()

static func get_hostname_win() -> String:
	@warning_ignore("int_as_enum_without_cast")
	return IP.resolve_hostname(OS.get_environment("COMPUTERNAME"),1)

static func get_hostname_unix() -> String:
	@warning_ignore("int_as_enum_without_cast")
	return IP.resolve_hostname(OS.get_environment("HOSTNAME"),1)

static func get_hostname_desktop() -> String:
	if OS.has_environment("windows"):
		return get_hostname_win() 
	elif OS.has_environment("x11") or OS.has_environment("OSX"):
		return get_hostname_unix()
	else:
		return "Not Desktop"

static func get_loopback_hostname() -> String:
	return IP.resolve_hostname(loopback)

static func get_localhost_hostname() -> String:
	return IP.resolve_hostname(localhost)

func on_peer_disconnected(peer_id: int) -> void:
	print("Peer %s disconnected."%[peer_id])
	reset()
	status.set_text("offline")

# Client connection funcs
func on_connection_succeeded() -> void:
	print("Connection succeeded!")
	@warning_ignore("static_called_on_instance")
	UI.disconnect_all_signals(multiplayer)
	setup_client_connections()
	# lmao
	status.set_text("connected %s"%ipinput.get_text())

func on_connection_failed() -> void:
	print("Connection failed.")
	reset()

# Client funcs
func on_server_disconnected() -> void:
	print("Server disconnected.")
	reset()
	status.set_text("offline")

func on_peer_connected(peer_id: int) -> void:
	print("Peer %s connected."%[peer_id])
	status.set_text("server (connected %s)"%[peer.get_peer(peer_id).get_remote_address()])
	toggle_opposite.bind(!send_mode).rpc()

static func disconnect_all_signals(obj: Object) -> void:
	for sig in obj.get_signal_list():
		disconnect_all_signal_connections(obj,sig.name)

static func disconnect_all_connections(sig: Signal) -> void:
	for connection in sig.get_connections():
		sig.disconnect(connection.callable)

static func disconnect_all_signal_connections(obj: Object, sig: String) -> void:
	var connections: Array[Dictionary] = obj.get_signal_connection_list(sig)
	for connection in connections:
		obj.disconnect(sig,connection.callable)

static func signal_disconnect_all_connections(sig: Signal) -> void:
	var connections: Array[Dictionary] = sig.get_connections()
	for connection in connections:
		sig.disconnect(connection.callable)

static func connect_signal_if_not_already(sig: Signal, callable: Callable) -> void:
	if !sig.is_connected(callable):
		sig.connect(callable)


func on_file_selected(path: String) -> void:
	file_location = path

func _on_toggle_button_toggled(toggled_on: bool) -> void:
	send_mode = toggled_on
	toggle_opposite.bind(!toggled_on).rpc()

var send_mode: bool

@onready var toggle_button: Button = $ToggleButton
@rpc func toggle_opposite(toggled: bool) -> void:
	toggle_button.set_pressed_no_signal(toggled)
	send_mode = toggled

@rpc func send(bytes: PackedByteArray) -> void:
	if send_mode == false:
		return print("received bytes while pitching")
	
	bytes_to_json(bytes)

@onready var files: FileDialog = $FileDialog
func _on_popup_pressed() -> void:
	files.popup_centered()
